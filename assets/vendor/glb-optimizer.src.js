// Shrinks a .glb in the browser before upload: fewer triangles, compressed geometry (Meshopt),
// textures resized to <= 1024 px and re-encoded as WebP. Bundled into assets/vendor/glb-optimizer.js.
import { WebIO, Logger } from '@gltf-transform/core';
import { ALL_EXTENSIONS, EXTTextureWebP } from '@gltf-transform/extensions';
import { dedup, prune, weld, simplify, meshopt } from '@gltf-transform/functions';
import { MeshoptSimplifier, MeshoptEncoder, MeshoptDecoder } from 'meshoptimizer';

function vertexCount(doc) {
  let n = 0;
  for (const m of doc.getRoot().listMeshes()) for (const p of m.listPrimitives()) n += p.getAttribute('POSITION')?.getCount() || 0;
  return n;
}
function textures(maxSize, onStep) {
  return async (doc) => {
    let webp = false;
    const list = doc.getRoot().listTextures();
    for (let i = 0; i < list.length; i++) {
      const t = list[i], img = t.getImage(), mime = t.getMimeType();
      if (!img || !/image\/(png|jpeg|webp)/.test(mime)) continue;
      onStep?.(`ảnh vân ${i + 1}/${list.length}`);
      const bmp = await createImageBitmap(new Blob([img], { type: mime }), { colorSpaceConversion: 'none', premultiplyAlpha: 'none' });
      const k = Math.min(1, maxSize / Math.max(bmp.width, bmp.height)), w = Math.max(1, Math.round(bmp.width * k)), h = Math.max(1, Math.round(bmp.height * k));
      if (k === 1 && mime === 'image/webp') { bmp.close(); continue; }
      const c = new OffscreenCanvas(w, h); c.getContext('2d').drawImage(bmp, 0, 0, w, h); bmp.close();
      const blob = await c.convertToBlob({ type: 'image/webp', quality: 0.85 });
      const out = new Uint8Array(await blob.arrayBuffer());
      if (out.byteLength >= img.byteLength && k === 1) continue; // not worth it
      t.setImage(out).setMimeType(blob.type);
      if (blob.type === 'image/webp') webp = true;
    }
    if (webp) doc.createExtension(EXTTextureWebP).setRequired(true);
  };
}
/** @returns {Promise<{buf: Uint8Array, before: number, after: number, vertsBefore: number, vertsAfter: number} | null>} null = left as is */
export async function optimizeGlb(input, { maxVerts = 150000, maxTexture = 1024, onStep } = {}) {
  await Promise.all([MeshoptSimplifier.ready, MeshoptEncoder.ready, MeshoptDecoder.ready]);
  const io = new WebIO().registerExtensions(ALL_EXTENSIONS).registerDependencies({ 'meshopt.decoder': MeshoptDecoder, 'meshopt.encoder': MeshoptEncoder });
  const bytes = input instanceof Uint8Array ? input : new Uint8Array(input);
  onStep?.('đọc mô hình');
  const doc = await io.readBinary(bytes);
  doc.setLogger(new Logger(Logger.Verbosity.WARN));
  const used = doc.getRoot().listExtensionsUsed().map(e => e.extensionName);
  if (used.includes('KHR_draco_mesh_compression')) return null; // already compressed, decoding it here is not supported
  const vertsBefore = vertexCount(doc), ratio = Math.min(1, maxVerts / Math.max(1, vertsBefore));
  const steps = [dedup(), prune()];
  if (ratio < 0.95) steps.push(weld(), simplify({ simplifier: MeshoptSimplifier, ratio, error: 0.001, lockBorder: true }));
  steps.push(textures(maxTexture, onStep));
  for (const s of steps) await doc.transform(s);
  onStep?.('nén hình học');
  await doc.transform(meshopt({ encoder: MeshoptEncoder, level: 'medium' }));
  const buf = await io.writeBinary(doc);
  return { buf, before: bytes.byteLength, after: buf.byteLength, vertsBefore, vertsAfter: vertexCount(doc) };
}
