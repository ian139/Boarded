'use client';

import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { resourceAPI } from '@/lib/api/client';
import type { Wall } from '@boarded/shared/types';

// Default wall
export const DEFAULT_WALL: Wall = {
  id: 'default-wall',
  user_id: 'local',
  name: 'Home Wall',
  image_url: '/walls/default-wall.jpg',
  image_width: 3001,
  image_height: 2733,
  is_public: true,
  created_at: new Date().toISOString(),
  updated_at: new Date().toISOString(),
};

let wallFetchGeneration = 0;
let wallAuthGeneration = 0;
let verifiedWallOwner: string | undefined;
type LocalWall = Wall & { _derivedFromRoute?: boolean };

function isDerivedWall(wall: Wall) {
  return Boolean(
    (wall as LocalWall)._derivedFromRoute ||
    /^Imported Wall [A-Z0-9]{4}$/i.test(wall.name)
  );
}

function isLocalWall(wall: Wall) {
  return wall.id === 'default-wall' ||
    wall.user_id === 'local' ||
    (wall.user_id === 'local-user' && !isDerivedWall(wall));
}

interface WallsState {
  walls: Wall[];
  selectedWall: Wall | null;

  // Actions
  setSelectedWall: (wall: Wall | null) => void;
  addWall: (wall: Wall) => Promise<boolean>;
  updateWall: (id: string, updates: Partial<Wall>) => Promise<boolean>;
  deleteWall: (id: string) => Promise<boolean>;
  getWallById: (id: string) => Wall | undefined;
  clearRemoteWalls: (currentUserId?: string) => void;
  // Sync actions
  fetchWalls: () => Promise<void>;
}

export const useWallsStore = create<WallsState>()(
  persist(
    (set, get) => ({
      walls: [DEFAULT_WALL],
      selectedWall: DEFAULT_WALL,

      setSelectedWall: (wall) => set({ selectedWall: wall }),

      // The server returns public walls and the verified owner's private walls.
      fetchWalls: async () => {
        const fetchGeneration = ++wallFetchGeneration;

        try {
          const { user } = await resourceAPI.session();
          if (fetchGeneration !== wallFetchGeneration || user?.id !== verifiedWallOwner) return;
          const currentUserId = user?.id || 'local-user';
          const remoteWalls = await resourceAPI.request<Wall[]>('/api/walls');
          const { user: latestUser } = await resourceAPI.session();
          if (
            fetchGeneration !== wallFetchGeneration ||
            (latestUser?.id || 'local-user') !== currentUserId
          ) {
            return;
          }

          if (remoteWalls) {
            const localWalls = get().walls.filter(isLocalWall);
            const mergedWalls = [
              ...localWalls,
              ...remoteWalls.filter(rw => !localWalls.some(lw => lw.id === rw.id))
            ];
            set({ walls: mergedWalls });
          }
        } catch (error) {
          console.error('Error fetching walls:', error);
        }
      },

      clearRemoteWalls: (currentUserId) => {
        wallFetchGeneration += 1;
        wallAuthGeneration += 1;
        verifiedWallOwner = currentUserId;
        set((state) => {
          const selected = state.selectedWall;
          const selectedIsLocal = selected ? isLocalWall(selected) : false;
          return {
            walls: state.walls.filter(isLocalWall),
            selectedWall: selectedIsLocal ? selected : DEFAULT_WALL,
          };
        });
      },

      addWall: async (wall) => {
        const authGeneration = wallAuthGeneration;
        // Add to local state immediately and remove it again if persistence fails.
        set((state) => ({
          walls: [...state.walls, wall],
        }));

        // Local-only walls are intentionally not sent to the server.
        if (wall.user_id === 'local-user' || wall.user_id === 'local') return true;

        try {
          const { user } = await resourceAPI.session();
          if (authGeneration !== wallAuthGeneration) return false;
          if (!user || user.id !== wall.user_id) throw new Error('Unable to authenticate wall owner');
          const saved = await resourceAPI.request<Wall>('/api/walls', {
            method: 'POST',
            body: JSON.stringify({
              id: wall.id,
              name: wall.name,
              description: wall.description,
              image_url: wall.image_url,
              image_width: wall.image_width,
              image_height: wall.image_height,
              is_public: wall.is_public,
            }),
          });
          if (authGeneration !== wallAuthGeneration) return false;
          set((state) => ({ walls: state.walls.map((candidate) => candidate.id === wall.id ? saved : candidate) }));
          return true;
        } catch (error) {
          console.error('Error saving wall:', error);
          if (authGeneration !== wallAuthGeneration) return false;
          set((state) => ({ walls: state.walls.filter((candidate) => candidate.id !== wall.id) }));
          return false;
        }
      },

      updateWall: async (id, updates) => {
        const current = get().walls.find((wall) => wall.id === id);
        const authGeneration = wallAuthGeneration;
        if (!current) return false;

        const next = { ...current, ...updates, updated_at: new Date().toISOString() };
        set((state) => ({
          walls: state.walls.map((wall) => wall.id === id ? next : wall),
          selectedWall: state.selectedWall?.id === id ? next : state.selectedWall,
        }));

        // Default and local-only walls are persisted by the local store only.
        if (id === 'default-wall' || current.user_id === 'local-user' || current.user_id === 'local') {
          return true;
        }

        try {
          const { name, description, image_url, image_width, image_height, is_public } = updates;
          const saved = await resourceAPI.request<Wall>(`/api/walls/${encodeURIComponent(id)}`, {
            method: 'PATCH',
            body: JSON.stringify({ name, description, image_url, image_width, image_height, is_public }),
          });
          if (authGeneration !== wallAuthGeneration) return false;
          set((state) => ({
            walls: state.walls.map((wall) => wall.id === id ? saved : wall),
            selectedWall: state.selectedWall?.id === id ? saved : state.selectedWall,
          }));
          return true;
        } catch (error) {
          console.error('Error updating wall:', error);
          if (authGeneration !== wallAuthGeneration) return false;
          set((state) => ({
            walls: state.walls.map((wall) => wall.id === id ? current : wall),
            selectedWall: state.selectedWall?.id === id ? current : state.selectedWall,
          }));
          return false;
        }
      },

      deleteWall: async (id) => {
        if (id === 'default-wall') return false;
        const wall = get().walls.find((candidate) => candidate.id === id);
        if (!wall) return false;
        const authGeneration = wallAuthGeneration;
        const wallIndex = get().walls.findIndex((candidate) => candidate.id === id);
        const selected = get().selectedWall;
        set((state) => ({
          walls: state.walls.filter((candidate) => candidate.id !== id),
          selectedWall: selected?.id === id ? DEFAULT_WALL : selected,
        }));

        // Local-only walls are intentionally removed from local state only.
        if (wall.user_id === 'local-user' || wall.user_id === 'local') return true;

        try {
          await resourceAPI.request(`/api/walls/${encodeURIComponent(id)}`, { method: 'DELETE' });
          return authGeneration === wallAuthGeneration;
        } catch (error) {
          console.error('Error deleting wall:', error);
          if (authGeneration !== wallAuthGeneration) return false;
          set((state) => {
            const walls = [...state.walls];
            walls.splice(Math.min(wallIndex, walls.length), 0, wall);
            return {
              walls,
              selectedWall: selected?.id === id ? wall : state.selectedWall,
            };
          });
          return false;
        }
      },

      getWallById: (id) => get().walls.find((w) => w.id === id),
    }),
    {
      name: 'boarded-walls',
      partialize: (state) => ({
        walls: state.walls,
        selectedWall: state.selectedWall,
      }),
      merge: (persisted, current) => {
        const cached = persisted as Partial<WallsState> | null;
        const walls = Array.isArray(cached?.walls) ? cached.walls.filter(isLocalWall) : current.walls;
        return {
          ...current,
          walls,
          selectedWall: cached?.selectedWall && isLocalWall(cached.selectedWall) ? cached.selectedWall : DEFAULT_WALL,
        };
      },
    }
  )
);
