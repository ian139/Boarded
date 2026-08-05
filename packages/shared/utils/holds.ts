import { nanoid } from 'nanoid/non-secure';
import { Hold, HoldType, HoldSize, HOLD_COLORS, HOLD_TYPE_CYCLE } from '../types';

const TOLERANCE = 3; // Tolerance in percentage for hold proximity detection

/**
 * Create a new hold at the given coordinates
 */
function createHold(
  x: number,
  y: number,
  type: HoldType,
  size: HoldSize
): Hold {
  return {
    id: nanoid(),
    x,
    y,
    type,
    color: HOLD_COLORS[type],
    sequence: null,
    size,
  };
}

/**
 * Check if a hold exists near the given coordinates (within tolerance)
 */
export function findHoldNearPoint(
  holds: Hold[],
  x: number,
  y: number,
  tolerance: number = TOLERANCE
): Hold | undefined {
  return holds.find(
    (hold) =>
      Math.abs(hold.x - x) < tolerance && Math.abs(hold.y - y) < tolerance
  );
}

/**
 * Convert pixel coordinates to percentage based on container dimensions
 */
export function pixelToPercentage(
  pixelX: number,
  pixelY: number,
  containerWidth: number,
  containerHeight: number
): { x: number; y: number } {
  return {
    x: (pixelX / containerWidth) * 100,
    y: (pixelY / containerHeight) * 100,
  };
}


/**
 * Add a hold to the array if no hold exists nearby
 */
export function addHold(
  holds: Hold[],
  x: number,
  y: number,
  type: HoldType,
  size: HoldSize = 'medium'
): Hold[] {
  const existingHold = findHoldNearPoint(holds, x, y);

  if (existingHold) {
    return holds; // Don't add if hold already exists nearby
  }

  const newHold = createHold(x, y, type, size);
  return [...holds, newHold];
}

/**
 * Remove a hold at or near the given coordinates
 */
export function removeHold(holds: Hold[], x: number, y: number): Hold[] {
  const holdToRemove = findHoldNearPoint(holds, x, y, TOLERANCE + 2);

  if (!holdToRemove) {
    return holds;
  }

  return holds.filter((hold) => hold.id !== holdToRemove.id);
}


/**
 * Get the next hold type in the cycle
 */
export function getNextHoldType(currentType: HoldType): HoldType {
  const currentIndex = HOLD_TYPE_CYCLE.indexOf(currentType);
  const nextIndex = (currentIndex + 1) % HOLD_TYPE_CYCLE.length;
  return HOLD_TYPE_CYCLE[nextIndex];
}

const HOLD_SIZE_CYCLE: HoldSize[] = ['small', 'medium', 'large'];

/**
 * Get the next hold size in the cycle
 */
export function getNextHoldSize(currentSize: HoldSize): HoldSize {
  const currentIndex = HOLD_SIZE_CYCLE.indexOf(currentSize);
  const nextIndex = (currentIndex + 1) % HOLD_SIZE_CYCLE.length;
  return HOLD_SIZE_CYCLE[nextIndex];
}

/**
 * Cycle a hold's type to the next in sequence and update its color
 */
export function cycleHoldType(holds: Hold[], holdId: string): Hold[] {
  return holds.map((hold) => {
    if (hold.id !== holdId) return hold;
    const nextType = getNextHoldType(hold.type);
    return {
      ...hold,
      type: nextType,
      color: HOLD_COLORS[nextType],
    };
  });
}


/**
 * Toggle sequence numbering on all holds
 */
export function toggleSequencing(holds: Hold[], enable: boolean): Hold[] {
  if (enable) {
    // Add sequence numbers to holds that don't have them
    return holds.map((hold, index) => ({
      ...hold,
      sequence: hold.sequence !== null ? hold.sequence : index + 1,
    }));
  } else {
    // Remove all sequence numbers
    return holds.map((hold) => ({
      ...hold,
      sequence: null,
    }));
  }
}
