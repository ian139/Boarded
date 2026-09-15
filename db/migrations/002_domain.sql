-- Active resources retain the historical column names and owner nullability.
-- Import into a fresh plain-PostgreSQL target using a reviewed identity mapping;
-- never run historical platform migrations here or overwrite existing tables.
-- Null owners remain null: they are not assigned to the importing operator.
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES public."user"(id) ON DELETE CASCADE,
  username TEXT NOT NULL UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  bio TEXT,
  home_area TEXT CHECK (home_area IS NULL OR char_length(btrim(home_area)) BETWEEN 1 AND 120),
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE public.walls (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  user_id UUID REFERENCES public."user"(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  description TEXT,
  image_url TEXT NOT NULL,
  image_width INTEGER DEFAULT 1920,
  image_height INTEGER DEFAULT 1080,
  is_public BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX walls_is_public_idx ON public.walls(is_public);
CREATE INDEX walls_user_id_idx ON public.walls(user_id);
CREATE TABLE public.routes (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  user_id UUID REFERENCES public."user"(id) ON DELETE SET NULL,
  user_name TEXT,
  -- Local/default wall identities are valid; intentionally no UUID cast or FK.
  wall_id TEXT NOT NULL,
  wall_image_url TEXT,
  wall_image_width INTEGER,
  wall_image_height INTEGER,
  name TEXT NOT NULL,
  description TEXT,
  grade_v TEXT,
  grade_font TEXT,
  rating NUMERIC(2,1),
  holds JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_public BOOLEAN DEFAULT true,
  view_count INTEGER DEFAULT 0,
  share_token TEXT UNIQUE,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX routes_wall_id_idx ON public.routes(wall_id);
CREATE INDEX routes_user_id_idx ON public.routes(user_id);
CREATE INDEX routes_is_public_idx ON public.routes(is_public);
CREATE INDEX routes_created_at_idx ON public.routes(created_at DESC, id DESC);
CREATE TABLE public.ascents (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  route_id UUID REFERENCES public.routes(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public."user"(id) ON DELETE SET NULL,
  user_name TEXT,
  grade_v TEXT,
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  notes TEXT,
  flashed BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX ascents_route_id_idx ON public.ascents(route_id);
CREATE INDEX ascents_user_id_idx ON public.ascents(user_id);
CREATE TABLE public.comments (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  route_id UUID REFERENCES public.routes(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public."user"(id) ON DELETE SET NULL,
  user_name TEXT,
  content TEXT NOT NULL,
  is_beta BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX comments_route_id_idx ON public.comments(route_id);
CREATE INDEX comments_user_id_idx ON public.comments(user_id);
CREATE TABLE public.route_likes (
  route_id UUID NOT NULL REFERENCES public.routes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public."user"(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (route_id, user_id)
);
CREATE INDEX route_likes_user_id_idx ON public.route_likes(user_id);

-- Disk keys are generated UUIDs, never client paths. Bytes are normalized WebP.
-- Importing legacy image URLs alone is NOT sufficient: inventory original bytes,
-- authenticate ownership, rewrite controlled URLs, and register references in one
-- transaction. A public route snapshot must not grant access to a private wall.
CREATE TABLE public.files (
  id UUID PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  owner_id UUID REFERENCES public."user"(id) ON DELETE SET NULL,
  purpose TEXT NOT NULL CHECK (purpose IN ('wall', 'route-snapshot', 'avatar')),
  entity_id UUID,
  wall_id TEXT,
  mime_type TEXT NOT NULL CHECK (mime_type = 'image/webp'),
  width INTEGER NOT NULL CHECK (width > 0),
  height INTEGER NOT NULL CHECK (height > 0),
  bytes BIGINT NOT NULL CHECK (bytes > 0),
  checksum TEXT NOT NULL CHECK (checksum ~ '^[0-9a-f]{64}$'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (id, purpose)
);
CREATE INDEX files_owner_id_idx ON public.files(owner_id);
CREATE INDEX files_created_at_idx ON public.files(created_at, id);
CREATE TABLE public.file_references (
  file_id UUID NOT NULL,
  purpose TEXT NOT NULL CHECK (purpose IN ('wall', 'route-snapshot', 'avatar')),
  entity_id UUID NOT NULL,
  PRIMARY KEY (purpose, entity_id),
  FOREIGN KEY (file_id, purpose) REFERENCES public.files(id, purpose) ON DELETE RESTRICT
);
CREATE INDEX file_references_file_id_idx ON public.file_references(file_id);

-- Association and cleanup both lock the files row before checking references.
-- This FK is the final guard against deleting bytes still in use. The server
-- binds files.entity_id once and checks it before inserting/replacing references.
-- Deletion of a wall removes only its own reference; route snapshots survive.
CREATE FUNCTION public.remove_resource_file_reference() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog AS $$
BEGIN
  DELETE FROM public.file_references
    WHERE purpose = TG_ARGV[0] AND entity_id = OLD.id;
  RETURN OLD;
END;
$$;
CREATE TRIGGER walls_remove_file_reference AFTER DELETE ON public.walls
  FOR EACH ROW EXECUTE FUNCTION public.remove_resource_file_reference('wall');
CREATE TRIGGER routes_remove_file_reference AFTER DELETE ON public.routes
  FOR EACH ROW EXECUTE FUNCTION public.remove_resource_file_reference('route-snapshot');
CREATE TRIGGER profiles_remove_file_reference AFTER DELETE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.remove_resource_file_reference('avatar');
CREATE FUNCTION public.touch_updated_at() RETURNS trigger
LANGUAGE plpgsql SET search_path = pg_catalog AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;
CREATE TRIGGER walls_updated_at BEFORE UPDATE ON public.walls
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER routes_updated_at BEFORE UPDATE ON public.routes
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER files_updated_at BEFORE UPDATE ON public.files
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
REVOKE ALL ON FUNCTION public.remove_resource_file_reference(), public.touch_updated_at()
  FROM PUBLIC, boarded_app;
REVOKE ALL ON public.profiles, public.walls, public.routes, public.ascents,
  public.comments, public.route_likes, public.files, public.file_references
  FROM PUBLIC, boarded_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles, public.walls, public.routes,
  public.ascents, public.comments, public.files, public.file_references TO boarded_app;
GRANT SELECT, INSERT, DELETE ON public.route_likes TO boarded_app;
-- No public SQL counter RPC, auth functions, anonymous grants or storage platform
-- objects exist. The same-origin server enforces actor/parent/file visibility.
