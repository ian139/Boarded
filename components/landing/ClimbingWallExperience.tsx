'use client';

import { useEffect, useRef, useState, useSyncExternalStore } from 'react';
import { createPortal } from 'react-dom';
import type * as Three from 'three';

const MODEL_URL = '/walls/generated/boarded-wall.glb';
const POSTER_URL = '/walls/generated/boarded-wall-poster.webp';
const REDUCED_MOTION = '(prefers-reduced-motion: reduce)';
const YAW_LIMIT = Math.PI / 4;
const YAW_PHASE_SPEED = (Math.PI * 2 / 90) / YAW_LIMIT;
const clamp = (value: number) => Math.max(0, Math.min(1, value));
const smooth = (start: number, end: number, value: number) => {
  const t = clamp((value - start) / (end - start));
  return t * t * (3 - 2 * t);
};
const mix = (a: number, b: number, t: number) => a + (b - a) * t;
function subscribeMotion(onChange: () => void) {
  const query = window.matchMedia(REDUCED_MOTION);
  query.addEventListener('change', onChange);
  return () => query.removeEventListener('change', onChange);
}
const getMotion = () => window.matchMedia(REDUCED_MOTION).matches;
const getServerMotion = () => true;
const subscribeHost = () => () => {};
const getHost = () => document.getElementById('landing-scene-host');
const getServerHost = () => null;

function disposeModel(root: Three.Object3D) {
  const geometries = new Set<Three.BufferGeometry>();
  const materials = new Set<Three.Material>();
  const textures = new Set<Three.Texture>();
  const skeletons = new Set<Three.Skeleton>();
  root.traverse((object) => {
    const mesh = object as Three.Mesh;
    if (mesh.geometry) geometries.add(mesh.geometry);
    if ((mesh as Three.SkinnedMesh).isSkinnedMesh) skeletons.add((mesh as Three.SkinnedMesh).skeleton);
    for (const material of mesh.material ? Array.isArray(mesh.material) ? mesh.material : [mesh.material] : []) {
      materials.add(material);
      for (const value of Object.values(material)) {
        if (value && typeof value === 'object' && 'isTexture' in value) textures.add(value as Three.Texture);
      }
    }
  });
  skeletons.forEach((skeleton) => skeleton.dispose());
  geometries.forEach((geometry) => geometry.dispose());
  materials.forEach((material) => material.dispose());
  textures.forEach((texture) => {
    texture.dispose();
    if (typeof ImageBitmap !== 'undefined' && texture.source.data instanceof ImageBitmap) texture.source.data.close();
  });
}

/** Time turns the sculpture; scroll scrubs the authored climb and summit exit. */
export function ClimbingWallExperience() {
  const anchorRef = useRef<HTMLDivElement>(null);
  const stageRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const scrimRef = useRef<HTMLDivElement>(null);
  const [status, setStatus] = useState<'loading' | 'ready' | 'failed'>('loading');
  const reducedMotion = useSyncExternalStore(subscribeMotion, getMotion, getServerMotion);
  const portalHost = useSyncExternalStore(subscribeHost, getHost, getServerHost);

  useEffect(() => {
    const anchor = anchorRef.current;
    const stage = stageRef.current;
    const canvas = canvasRef.current;
    const story = document.getElementById('wall-story');
    const rail = document.getElementById('wall-stage-track');
    const closing = document.querySelector<HTMLElement>('.landing-closing');
    const approach = document.getElementById('approach');
    if (reducedMotion || !portalHost || !anchor || !stage || !canvas || !story || !rail || !closing || !approach) return;

    let disposed = false;
    let initializing = false;
    let active = true;
    let failed = false;
    let firstFrame = true;
    let frame = 0;
    let previousTime = 0;
    let targetProgress = 0;
    let progress = 0;
    let yawPhase = 0;
    let width = window.innerWidth;
    let height = window.innerHeight;
    let anchorBox = anchor.getBoundingClientRect();
    let model: Three.Object3D | null = null;
    let renderer: Three.WebGLRenderer | null = null;
    let scene: Three.Scene | null = null;
    let camera: Three.OrthographicCamera | null = null;
    let composition: Three.Group | null = null;
    let rotation: Three.Group | null = null;
    let right: Three.Vector3 | null = null;
    let up: Three.Vector3 | null = null;
    let shadowLight: Three.DirectionalLight | null = null;
    let mixer: Three.AnimationMixer | null = null;
    let ascentAction: Three.AnimationAction | null = null;
    let ascentDuration = 0;
    let sampledAscent = -1;
    const abort = new AbortController();
    function readLayout() {
      width = window.innerWidth;
      height = window.innerHeight;
      anchorBox = anchor!.getBoundingClientRect();
      const mobile = width < 760;
      const start = mobile ? rail!.getBoundingClientRect().top + window.scrollY - 88 : story!.getBoundingClientRect().top + window.scrollY;
      const end = mobile
        ? approach!.getBoundingClientRect().top + window.scrollY - height * 0.10
        : closing!.getBoundingClientRect().top + window.scrollY - height * 0.12;
      targetProgress = clamp((window.scrollY - start) / Math.max(1, end - start));
      const storyBox = story!.getBoundingClientRect();
      const sculptureVisible = targetProgress >= 0.73 || (anchorBox.bottom > 0 && anchorBox.top < height);
      active = storyBox.bottom > 0 && storyBox.top < height && sculptureVisible;
      if (!active) {
        progress = targetProgress;
        previousTime = 0;
        stage!.style.visibility = 'hidden';
        anchor!.dataset.progress = progress.toFixed(5);
        anchor!.dataset.opacity = '0';
        anchor!.dataset.phase = 'gone';
      }
    }

    function requestRender() {
      if (!frame && !disposed && !failed && active && !document.hidden) frame = requestAnimationFrame(render);
    }

    function render(time: number) {
      frame = 0;
      if (disposed || failed || !active || document.hidden || !renderer || !scene || !camera || !composition || !rotation || !right || !up) return;
      const dt = previousTime ? Math.max(0, (time - previousTime) / 1000) : 0;
      previousTime = time;
      progress += (targetProgress - progress) * (1 - Math.exp(-dt * 11));
      if (Math.abs(targetProgress - progress) < 0.00008) progress = targetProgress;
      const ascent = clamp((progress - 0.08) / 0.57);
      // An exact summit sample can pause LoopOnce. Re-enable before every seek
      // so scrolling backward from the final frame always restores the climb.
      if (mixer && ascentAction && ascent !== sampledAscent) {
        ascentAction.enabled = true;
        ascentAction.paused = false;
        mixer.setTime(ascent * ascentDuration);
        sampledAscent = ascent;
      }
      const grow = smooth(0.73, 0.93, progress);
      const close = smooth(0.80, 0.90, progress);
      const exit = smooth(0.88, 0.93, progress);
      const center = smooth(0.73, 0.83, progress);
      const zoom = Math.exp(Math.log(40) * grow);
      const opacity = 1 - smooth(0.88, 0.93, progress);
      if (opacity > 0) {
        yawPhase = (yawPhase + dt * YAW_PHASE_SPEED) % (Math.PI * 2);
      }
      const yaw = Math.sin(yawPhase) * YAW_LIMIT;
      const viewHeight = Math.max(4.7, 4.7 * 1200 / 1440 / (anchorBox.width / anchorBox.height));
      const initialY = (width < 760 ? Math.max(anchorBox.top, 136) : anchorBox.top) + anchorBox.height / 2;
      const x = mix(anchorBox.left + anchorBox.width / 2, width * 0.53, center) + width * (0.36 * close + 1.2 * exit);
      const y = mix(initialY, height * 0.51, center) - height * (0.10 * close + 0.50 * exit);
      const worldScale = anchorBox.height / viewHeight * zoom;
      composition.scale.setScalar(worldScale);
      if (shadowLight) {
        Object.assign(shadowLight.shadow.camera, { left: -3.5 * worldScale, right: 3.5 * worldScale, top: 3.5 * worldScale, bottom: -3.5 * worldScale, near: 0.5 * worldScale, far: 18 * worldScale });
        shadowLight.shadow.normalBias = 0.012 * worldScale;
        shadowLight.shadow.camera.updateProjectionMatrix();
      }
      composition.position.copy(right).multiplyScalar(x - width / 2).addScaledVector(up, height / 2 - y);
      rotation.rotation.y = yaw;
      stage!.style.opacity = String(opacity);
      stage!.style.visibility = opacity === 0 ? 'hidden' : 'visible';
      if (scrimRef.current) scrimRef.current.style.opacity = String(smooth(0.74, 0.82, progress));
      rail!.style.setProperty('--wall-chrome-opacity', String(1 - smooth(0.03, 0.08, progress)));
      anchor!.dataset.progress = progress.toFixed(5);
      anchor!.dataset.yaw = yaw.toFixed(5);
      anchor!.dataset.scale = zoom.toFixed(4);
      anchor!.dataset.opacity = opacity.toFixed(4);
      anchor!.dataset.ascent = ascent.toFixed(5);
      anchor!.dataset.clipTime = (ascent * ascentDuration).toFixed(4);
      anchor!.dataset.phase = progress < 0.08 ? 'showcase' : progress < 0.65 ? 'climb' : progress < 0.73 ? 'summit' : progress < 0.88 ? 'expand' : opacity > 0 ? 'exit' : 'gone';
      if (opacity > 0) renderer.render(scene, camera);
      if (firstFrame) { firstFrame = false; setStatus('ready'); readLayout(); }
      if (opacity > 0 || progress !== targetProgress) requestRender();
      else previousTime = 0;
    }

    function resize() {
      readLayout();
      if (!initializing) void initialize();
      if (renderer && camera) {
        const cap = width < 760 ? 1.35 : 1.5;
        renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, cap, Math.sqrt(2_000_000 / (width * height))));
        renderer.setSize(width, height, false);
        camera.left = -width / 2;
        camera.right = width / 2;
        camera.top = height / 2;
        camera.bottom = -height / 2;
        camera.updateProjectionMatrix();
      }
      requestRender();
    }

    async function initialize() {
      if (initializing || disposed || !active) return;
      initializing = true;
      setStatus('loading');
      try {
        const [THREE, { GLTFLoader }] = await Promise.all([import('three'), import('three/addons/loaders/GLTFLoader.js')]);
        if (disposed) return;
        renderer = new THREE.WebGLRenderer({ canvas: canvas!, alpha: true, antialias: true, powerPreference: 'low-power' });
        renderer.outputColorSpace = THREE.SRGBColorSpace;
        renderer.toneMapping = THREE.AgXToneMapping;
        renderer.toneMappingExposure = 1.05;
        renderer.setClearColor(0x000000, 0);
        renderer.shadowMap.enabled = true;
        renderer.shadowMap.type = THREE.PCFShadowMap;
        scene = new THREE.Scene();
        // Pixel-scaled orthographic framing keeps the backing canvas viewport-sized
        // while the sculpture grows far beyond it, without a giant render target.
        camera = new THREE.OrthographicCamera(-width / 2, width / 2, height / 2, -height / 2, 0.1, 200000);
        camera.position.set(5.9, 5.13, 10).normalize().multiplyScalar(100000);
        camera.lookAt(0, 0, 0);
        camera.updateMatrixWorld();
        right = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 0);
        up = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 1);
        composition = new THREE.Group();
        rotation = new THREE.Group();
        composition.add(rotation);
        scene.add(composition);
        // Lights share the composition transform so enlarging the wall preserves
        // the approved studio shading and its one modest contact-shadow map.
        const lights = new THREE.Group();
        lights.add(new THREE.HemisphereLight(0xf2f1ff, 0x353641, 1.8));
        const key = new THREE.DirectionalLight(0xffeed7, 3.6);
        key.position.set(-3.5, 6, 4.5);
        key.castShadow = true;
        shadowLight = key;
        key.shadow.mapSize.set(1024, 1024);
        Object.assign(key.shadow.camera, { left: -3.5, right: 3.5, top: 3.5, bottom: -3.5, near: 0.5, far: 18 });
        key.shadow.radius = 3;
        key.shadow.intensity = 0.35;
        key.shadow.normalBias = 0.012;
        key.shadow.bias = -0.00015;
        lights.add(key, key.target);
        const fill = new THREE.DirectionalLight(0xceccff, 1.8);
        fill.position.set(4, 2, 1);
        lights.add(fill, fill.target);
        const rim = new THREE.DirectionalLight(0xf4f2eb, 2.7);
        rim.position.set(-1, 3, -5);
        lights.add(rim, rim.target);
        composition.add(lights);

        const response = await fetch(MODEL_URL, { signal: abort.signal });
        if (!response.ok) throw new Error('Wall asset unavailable');
        const gltf = await new GLTFLoader().parseAsync(await response.arrayBuffer(), '/walls/generated/');
        if (disposed) { disposeModel(gltf.scene); return; }
        model = gltf.scene;
        model.traverse((object) => {
          if ((object as Three.Mesh).isMesh) {
            object.castShadow = true;
            object.receiveShadow = true;
          }
          // The climber moves beyond its bind-pose bounds during the ascent.
          // Keep this small animated mesh visible; static wall meshes still cull.
          if ((object as Three.SkinnedMesh).isSkinnedMesh) object.frustumCulled = false;
        });
        rotation.add(model);
        const ascentClip = gltf.animations.find((clip) => clip.name === 'ClimberAscent');
        if (ascentClip) {
          mixer = new THREE.AnimationMixer(model);
          ascentDuration = ascentClip.duration;
          ascentAction = mixer.clipAction(ascentClip);
          ascentAction.setLoop(THREE.LoopOnce, 1);
          ascentAction.clampWhenFinished = true;
          ascentAction.play();
        }
        anchor!.dataset.hasAscent = String(Boolean(ascentClip));
        readLayout();
        progress = targetProgress;
        resize();
      } catch {
        if (!disposed) {
          failed = true;
          setStatus('failed');
          stage!.style.visibility = 'hidden';
          if (model) { disposeModel(model); model = null; }
          renderer?.dispose();
          renderer?.forceContextLoss();
          renderer = null;
        }
      }
    }

    function onScroll() { readLayout(); void initialize(); requestRender(); }
    function onVisibility() {
      if (document.hidden) { cancelAnimationFrame(frame); frame = 0; previousTime = 0; }
      else { readLayout(); requestRender(); }
    }
    function onContextLost(event: Event) {
      event.preventDefault();
      failed = true;
      setStatus('failed');
      stage!.style.visibility = 'hidden';
      rail!.style.removeProperty('--wall-chrome-opacity');
      cancelAnimationFrame(frame);
      frame = 0;
    }

    readLayout();
    void initialize();
    const observer = new ResizeObserver(resize);
    observer.observe(anchor);
    observer.observe(story);
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', resize, { passive: true });
    document.addEventListener('visibilitychange', onVisibility);
    canvas.addEventListener('webglcontextlost', onContextLost);

    return () => {
      disposed = true;
      setStatus('loading');
      abort.abort();
      cancelAnimationFrame(frame);
      observer.disconnect();
      window.removeEventListener('scroll', onScroll);
      window.removeEventListener('resize', resize);
      document.removeEventListener('visibilitychange', onVisibility);
      canvas.removeEventListener('webglcontextlost', onContextLost);
      rail.style.removeProperty('--wall-chrome-opacity');
      mixer?.stopAllAction();
      if (model) { mixer?.uncacheRoot(model); disposeModel(model); }
      renderer?.dispose();
      renderer?.forceContextLoss();
    };
  }, [reducedMotion, portalHost]);

  return <>
    <div className="landing-wall" ref={anchorRef} data-state={reducedMotion ? 'static' : status === 'ready' ? 'ready' : status === 'failed' ? 'fallback' : 'poster'}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img className="landing-wall-poster" src={POSTER_URL} alt="A playful climber reaching up a chalk climbing wall with colorful holds and an open timber frame." width="1200" height="1440" loading="eager" fetchPriority="high" />
      <div className="landing-ascent-hint" aria-hidden="true"><span>↓</span> Scroll to follow the climb</div>
    </div>
    {portalHost && !reducedMotion && createPortal(<div className="landing-scene" ref={stageRef}><canvas ref={canvasRef} aria-hidden="true" /><div className="landing-scene-scrim" ref={scrimRef} /></div>, portalHost)}
  </>;
}
