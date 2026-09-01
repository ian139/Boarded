import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const FONT_SHA256 = '6a9d9b79e12d1bacf936714597f04053de53c3728fefa926629856e82c69e129';
const OFL_SHA256 = '60700d351cac4650c51f3f9db318d2a420f8b45052dba2715eb5fec41f0f6956';

const ICON_SHA256 = {
  native1024: '376894365de8563635bb3e2767021ed5c62fe52c7d4613516e54b4ced1945530',
  web512: 'a43b36faa188d2542dfbd066581fe2f811df29ab43bac8f97284a687de966a69',
  web192: '2590cb3c43d3e2e1f48fd5c63a7d2bbb811957bc2281a2e22cdb319477813fee',
  apple180: '653f704e09bfc67f4f5900f5593c548771a15b9a86d6c35241cf04e175353157',
} as const;

const PNG_SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

function assertOpaquePng(path: string, width: number, height: number): void {
  const png = readFileSync(path);
  assert.equal(png.subarray(0, 8).equals(PNG_SIGNATURE), true, `${path} is not a PNG`);
  assert.equal(png.subarray(12, 16).toString('ascii'), 'IHDR', `${path} has no IHDR`);
  assert.equal(png.readUInt32BE(16), width, `${path} width mismatch`);
  assert.equal(png.readUInt32BE(20), height, `${path} height mismatch`);
  assert.equal(png[25], 2, `${path} must be opaque truecolor`);
}

function sha256(path: string): string {
  return createHash('sha256').update(readFileSync(path)).digest('hex');
}

describe('Boarded identity contract', () => {
  it('ships the canonical Cormorant Garamond TTF byte-for-byte on web and iOS', () => {
    const web = join(repoRoot, 'public', 'fonts', 'CormorantGaramond-SemiBoldItalic.ttf');
    const ios = join(repoRoot, 'apps', 'ios', 'Boarded', 'Boarded', 'CormorantGaramond-SemiBoldItalic.ttf');
    assert.equal(sha256(web), FONT_SHA256, 'web font hash mismatch');
    assert.equal(sha256(ios), FONT_SHA256, 'iOS font hash mismatch');
    assert.equal(readFileSync(web).equals(readFileSync(ios)), true, 'web and iOS fonts differ');
  });

  it('ships the pinned OFL license at the required path on web and iOS', () => {
    const web = join(repoRoot, 'licenses', 'Cormorant-Garamond-OFL.txt');
    const ios = join(repoRoot, 'apps', 'ios', 'Boarded', 'Boarded', 'Cormorant-Garamond-OFL.txt');
    assert.equal(sha256(web), OFL_SHA256, 'web license hash mismatch');
    assert.equal(sha256(ios), OFL_SHA256, 'iOS license hash mismatch');
  });

  it('ships pinned opaque PNG app icons derived from the accepted Boarded mark', () => {
    const app512 = join(repoRoot, 'app', 'icon.png');
    const public512 = join(repoRoot, 'public', 'icons', 'icon-512.png');
    const public192 = join(repoRoot, 'public', 'icons', 'icon-192.png');
    const apple180 = join(repoRoot, 'public', 'apple-touch-icon.png');
    const native1024 = join(
      repoRoot,
      'apps',
      'ios',
      'Boarded',
      'Boarded',
      'Assets.xcassets',
      'AppIcon.appiconset',
      'BoardedLogo.png',
    );

    assertOpaquePng(app512, 512, 512);
    assertOpaquePng(public512, 512, 512);
    assertOpaquePng(public192, 192, 192);
    assertOpaquePng(apple180, 180, 180);
    assertOpaquePng(native1024, 1024, 1024);
    assert.equal(readFileSync(app512).equals(readFileSync(public512)), true, '512px icons differ');
    assert.equal(sha256(app512), ICON_SHA256.web512, '512px icon hash mismatch');
    assert.equal(sha256(public192), ICON_SHA256.web192, '192px icon hash mismatch');
    assert.equal(sha256(apple180), ICON_SHA256.apple180, 'Apple touch icon hash mismatch');
    assert.equal(sha256(native1024), ICON_SHA256.native1024, 'native icon hash mismatch');
  });

  it('has no legacy alias', () => {
    const root = JSON.parse(readFileSync(join(repoRoot, 'package.json'), 'utf8')) as {
      dependencies: Record<string, string>;
    };
    const shared = JSON.parse(readFileSync(join(repoRoot, 'packages', 'shared', 'package.json'), 'utf8')) as {
      name: string;
    };
    const legacyAlias = '@' + 'climb' + 'set' + '/shared';
    assert.equal(shared.name, '@boarded/shared');
    assert.equal(root.dependencies['@boarded/shared'], '*');
    assert.equal(legacyAlias in root.dependencies, false);
  });
});
