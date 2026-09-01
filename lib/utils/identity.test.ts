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
  native1024: '5b76290fddc4d1c8d01b002dcd434c89faabf8c3ccef42be1562d45570eb2909',
  web512: '2445299c695d265bd600734586147274174e8eda14d2c7ce7032c79f76e0c2e9',
  web192: '3c53985f1220f3415713abf67b5cb499b2988c85e7236d05ac1fa37613aa13e5',
  apple180: '0083f2ef4059d633bcedbfdca4ea66c5a41c49b9db5efd5781068d3599f1fcfa',
} as const;

const PNG_SIGNATURE = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);

function assertOpaquePng(path: string, width: number, height: number): void {
  const png = readFileSync(path);
  assert.equal(png.subarray(0, 8).equals(PNG_SIGNATURE), true, `${path} is not a PNG`);
  assert.equal(png.subarray(12, 16).toString('ascii'), 'IHDR', `${path} has no IHDR`);
  assert.equal(png.readUInt32BE(16), width, `${path} width mismatch`);
  assert.equal(png.readUInt32BE(20), height, `${path} height mismatch`);
  assert.equal(png[25], 2, `${path} must be opaque truecolor`);

  let offset = 8;
  let hasStandardSrgb = false;
  while (offset + 12 <= png.length) {
    const chunkLength = png.readUInt32BE(offset);
    const chunkType = png.subarray(offset + 4, offset + 8).toString('ascii');
    assert.ok(offset + 12 + chunkLength <= png.length, `${path} has a truncated ${chunkType} chunk`);
    if (chunkType === 'sRGB') {
      hasStandardSrgb = chunkLength === 1 && png[offset + 8] === 0;
    }
    offset += 12 + chunkLength;
    if (chunkType === 'IEND') break;
  }
  assert.equal(hasStandardSrgb, true, `${path} must declare standard sRGB intent`);
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
