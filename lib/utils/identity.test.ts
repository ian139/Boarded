import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const FONT_SHA256 = '6a9d9b79e12d1bacf936714597f04053de53c3728fefa926629856e82c69e129';
const OFL_SHA256 = '60700d351cac4650c51f3f9db318d2a420f8b45052dba2715eb5fec41f0f6956';

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
