'use client';

import { useEffect, useRef, useState, useSyncExternalStore } from 'react';

const GLB_URL = '/walls/generated/photo-wall-relief-web.glb';
const FALLBACK_URL = '/walls/generated/photo-wall-relief-web-fallback.webp';

function clamp(value: number, min: number, max: number): number {
  return Math.min(Math.max(value, min), max);
}

function lerp(current: number, target: number, speed: number): number {
  return current + (target - current) * speed;
}
function subscribeReducedMotion(onChange: () => void): () => void {
  const media = window.matchMedia('(prefers-reduced-motion: reduce)');
  media.addEventListener('change', onChange);
  return () => media.removeEventListener('change', onChange);
}

function getReducedMotionSnapshot(): boolean {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function getServerReducedMotionSnapshot(): boolean {
  return true;
}


export function PhotoWallHero() {
  const containerRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [isReady, setIsReady] = useState(false);
  const prefersReducedMotion = useSyncExternalStore(
    subscribeReducedMotion,
    getReducedMotionSnapshot,
    getServerReducedMotionSnapshot
  );


  useEffect(() => {
    const container = containerRef.current;
    const canvas = canvasRef.current;
    if (prefersReducedMotion || !container || !canvas) return;

    let disposed = false;
    let rafId: number | null = null;
    let isRendering = false;
    let hasRenderedFirstFrame = false;

    // Three.js instances
    let renderer: import('three').WebGLRenderer | null = null;
    let scene: import('three').Scene | null = null;
    let camera: import('three').PerspectiveCamera | null = null;
    let pivot: import('three').Group | null = null;
    let dirLight: import('three').DirectionalLight | null = null;
    let hemiLight: import('three').HemisphereLight | null = null;
    let modelBoxSize: import('three').Vector3 | null = null;

    // Animation state
    let targetYaw = 0;
    let targetPitch = 0;
    let targetLightX = 0;
    let targetLightIntensity = 2.6;

    let currentYaw = 0;
    let currentPitch = 0;
    let currentLightX = 0;
    let currentLightIntensity = 2.6;

    function fitCamera(
      cam: import('three').PerspectiveCamera,
      size: import('three').Vector3,
      margin = 1.12
    ) {
      const vFov = (cam.fov * Math.PI) / 180;
      const hFov = 2 * Math.atan(Math.tan(vFov / 2) * cam.aspect);
      const distY = (size.y / 2 / Math.tan(vFov / 2)) * margin;
      const distX = (size.x / 2 / Math.tan(hFov / 2)) * margin;
      const dist = Math.max(distY, distX) + size.z / 2;

      cam.position.set(0, 0, dist);
      cam.lookAt(0, 0, 0);
      cam.updateProjectionMatrix();
    }

    function updateTargets() {
      if (!container) return;
      const rect = container.getBoundingClientRect();
      const viewportHeight = window.innerHeight;
      const progress = clamp(
        (viewportHeight - rect.top) / (viewportHeight + rect.height),
        0,
        1
      );

      // Map progress:
      // yaw: -0.06 -> +0.06 rad
      // pitch: +0.02 -> -0.02 rad
      // light X: -3 -> +3
      // light intensity: 2.4 -> 2.8
      targetYaw = -0.06 + progress * 0.12;
      targetPitch = 0.02 - progress * 0.04;
      targetLightX = -3 + progress * 6;
      targetLightIntensity = 2.4 + progress * 0.4;
    }

    function renderFrame() {
      if (disposed || !renderer || !scene || !camera || !pivot || !dirLight) {
        isRendering = false;
        return;
      }

      currentYaw = lerp(currentYaw, targetYaw, 0.08);
      currentPitch = lerp(currentPitch, targetPitch, 0.08);
      currentLightX = lerp(currentLightX, targetLightX, 0.08);
      currentLightIntensity = lerp(currentLightIntensity, targetLightIntensity, 0.08);

      pivot.rotation.y = currentYaw;
      pivot.rotation.x = currentPitch;
      dirLight.position.x = currentLightX;
      dirLight.intensity = currentLightIntensity;

      renderer.render(scene, camera);

      if (!hasRenderedFirstFrame) {
        hasRenderedFirstFrame = true;
        setIsReady(true);
      }

      const deltaYaw = Math.abs(currentYaw - targetYaw);
      const deltaPitch = Math.abs(currentPitch - targetPitch);
      const deltaLightX = Math.abs(currentLightX - targetLightX);
      const deltaLightInt = Math.abs(currentLightIntensity - targetLightIntensity);

      if (
        deltaYaw > 0.0005 ||
        deltaPitch > 0.0005 ||
        deltaLightX > 0.0005 ||
        deltaLightInt > 0.0005
      ) {
        rafId = requestAnimationFrame(renderFrame);
      } else {
        isRendering = false;
        rafId = null;
      }
    }

    function requestRender() {
      if (disposed) return;
      if (!isRendering) {
        isRendering = true;
        rafId = requestAnimationFrame(renderFrame);
      }
    }

    function onScroll() {
      updateTargets();
      requestRender();
    }

    function onContextLost(event: Event) {
      event.preventDefault();
      setIsReady(false);
      if (rafId !== null) {
        cancelAnimationFrame(rafId);
        rafId = null;
      }
      isRendering = false;
    }

    canvas.addEventListener('webglcontextlost', onContextLost, false);

    let resizeObserver: ResizeObserver | null = null;

    // Asynchronously import Three and GLTFLoader
    Promise.all([
      import('three'),
      import('three/addons/loaders/GLTFLoader.js'),
    ])
      .then(([THREE, { GLTFLoader }]) => {
        if (disposed) return;

        try {
          renderer = new THREE.WebGLRenderer({
            canvas,
            antialias: true,
            alpha: true,
            powerPreference: 'high-performance',
          });
        } catch {
          // WebGL unsupported or context failed
          setIsReady(false);
          return;
        }

        renderer.outputColorSpace = THREE.SRGBColorSpace;
        renderer.toneMapping = THREE.AgXToneMapping;
        renderer.toneMappingExposure = 1.0;
        renderer.shadowMap.enabled = false;
        renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));

        const rect = container.getBoundingClientRect();
        const width = Math.max(rect.width, 1);
        const height = Math.max(rect.height, 1);
        renderer.setSize(width, height, false);

        scene = new THREE.Scene();
        camera = new THREE.PerspectiveCamera(40, width / height, 0.1, 100);

        pivot = new THREE.Group();
        scene.add(pivot);

        hemiLight = new THREE.HemisphereLight(0xffffff, 0x111118, 0.65);
        scene.add(hemiLight);

        dirLight = new THREE.DirectionalLight(0xf4f2eb, 2.6);
        dirLight.position.set(0, 4, 6);
        scene.add(dirLight);

        updateTargets();
        currentYaw = targetYaw;
        currentPitch = targetPitch;
        currentLightX = targetLightX;
        currentLightIntensity = targetLightIntensity;

        const loader = new GLTFLoader();
        loader.load(
          GLB_URL,
          (gltf) => {
            if (disposed || !pivot || !camera) return;
            const model = gltf.scene;
            pivot.add(model);

            const box = new THREE.Box3().setFromObject(model);
            const center = box.getCenter(new THREE.Vector3());
            modelBoxSize = box.getSize(new THREE.Vector3());

            model.position.sub(center);

            fitCamera(camera, modelBoxSize, 1.12);
            requestRender();
          },
          undefined,
          () => {
            if (!disposed) {
              setIsReady(false);
            }
          }
        );

        resizeObserver = new ResizeObserver((entries) => {
          if (disposed || !renderer || !camera) return;
          for (const entry of entries) {
            const entryWidth = Math.max(entry.contentRect.width, 1);
            const entryHeight = Math.max(entry.contentRect.height, 1);
            renderer.setSize(entryWidth, entryHeight, false);
            camera.aspect = entryWidth / entryHeight;
            if (modelBoxSize) {
              fitCamera(camera, modelBoxSize, 1.12);
            } else {
              camera.updateProjectionMatrix();
            }
            requestRender();
          }
        });

        resizeObserver.observe(container);
        window.addEventListener('scroll', onScroll, { passive: true });
        requestRender();
      })
      .catch(() => {
        if (!disposed) {
          setIsReady(false);
        }
      });

    return () => {
      disposed = true;
      if (rafId !== null) {
        cancelAnimationFrame(rafId);
      }
      window.removeEventListener('scroll', onScroll);
      canvas.removeEventListener('webglcontextlost', onContextLost);
      if (resizeObserver) {
        resizeObserver.disconnect();
      }

      if (scene) {
        scene.traverse((child) => {
          if ('geometry' in child && child.geometry) {
            (child.geometry as import('three').BufferGeometry).dispose();
          }
          if ('material' in child && child.material) {
            const mat = child.material as import('three').Material | import('three').Material[];
            if (Array.isArray(mat)) {
              mat.forEach((m) => m.dispose());
            } else if (mat && typeof (mat as import('three').Material).dispose === 'function') {
              (mat as import('three').Material).dispose();
            }
          }
        });
      }

      if (renderer) {
        renderer.dispose();
      }
    };
  }, [prefersReducedMotion]);

  return (
    <div
      ref={containerRef}
      role="img"
      aria-label="A relief model of a climbing wall covered in colorful holds."
      className="relative w-full h-full min-h-[300px] md:min-h-[440px] flex items-center justify-center overflow-hidden rounded-2xl bg-gradient-to-b from-[#171A22] to-[#0A0B10] select-none"
    >
      {/* Stable fallback image, visible during load, reduced-motion, and WebGL failure */}
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img
        src={FALLBACK_URL}
        alt=""
        className={`absolute inset-0 w-full h-full object-contain pointer-events-none transition-opacity duration-[180ms] ease-out ${
          isReady ? 'opacity-0' : 'opacity-100'
        }`}
        loading="eager"
        decoding="async"
      />
      {/* Canvas for Three.js WebGL, strictly non-interactive */}
      {!prefersReducedMotion && (
        <canvas
          ref={canvasRef}
          aria-hidden="true"
          tabIndex={-1}
          className="w-full h-full pointer-events-none block"
          style={{ touchAction: 'none' }}
        />
      )}
    </div>
  );
}
