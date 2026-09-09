import struct, json, sys

CT = {5126: ("<f", 4), 5125: ("<h", 2), 5123: ("<b", 1), 30035: ("<I", 4), 30036: ("<Q", 8)}

def parse_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, version, total = struct.unpack_from("<4sII", data, 0)
    assert magic == b"glTF" and version == 2
    off = 12
    doc = None
    buf = b""
    JSON_T = struct.unpack("<I", b"JSON")[0]
    BIN_T = struct.unpack("<I", b"BIN\0")[0]
    while off < len(data):
        clen, ctype = struct.unpack_from("<II", data, off)
        off += 8
        chunk = data[off:off + clen]
        off += clen
        if ctype == JSON_T:
            doc = json.loads(chunk)
        elif ctype == BIN_T:
            buf = chunk
    return doc, buf

def geom_stats(path):
    doc, buf = parse_glb(path)
    stats = []
    total_tris = 0
    for m in doc.get("meshes", []):
        for prim in m.get("primitives", []):
            attrs = prim.get("attributes", {})
            raw, elem, ptype = None, 4, "VEC3"
            n = 0
            mins = maxs = None
            if "POSITION" in attrs:
                acc = doc["accessors"][attrs["POSITION"]]
                bv = doc["bufferViews"][acc["bufferView"]]
                off = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
                fmt, elem = CT.get(acc["componentType"], ("<f", 4))
                dims = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 4}[acc.get("type", "VEC3")]
                count = acc["count"]
                if acc["componentType"] == 5126:
                    vals = struct.unpack_from("<" + "f" * (count * dims), buf, off)
                    mins = [None] * dims
                    maxs = [None] * dims
                    for i in range(count):
                        for d in range(dims):
                            v = vals[i * dims + d]
                            if mins[d] is None or v < mins[d]:
                                mins[d] = v
                            if maxs[d] is None or v > maxs[d]:
                                maxs[d] = v
                    n = count
            idx = prim.get("indices")
            if idx is not None:
                icount = doc["accessors"][idx]["count"]
                total_tris += icount // 3
            stats.append({
                "mesh": m.get("name"),
                "material": (lambda mi: doc.get("materials", [{}])[mi].get("name"))(prim["material"]) if prim.get("material") is not None else None,
                "vertices": n,
                "trigons": icount // 3 if idx is not None else None,
                "min": mins,
                "max": maxs,
                "extents": ([maxs[d] - mins[d] for d in range(len(mins))]) if mins is not None else None,
            })
    named = []
    for k in ("nodes", "meshes", "materials"):
        for obj in doc.get(k, []):
            if isinstance(obj, dict) and obj.get("name"):
                named.append(f"{k}:{obj['name']}")
    return {"file": path, "asset": doc.get("asset"), "named": named, "prims": stats, "total_tris": total_tris}

for p in sys.argv[1:]:
    print(json.dumps(geom_stats(p), indent=1))
