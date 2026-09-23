import {onObjectFinalized} from "firebase-functions/v2/storage";
import sharp from "sharp";
import {storage} from "../shared/firestore";

export const generateProfileTeaser = onObjectFinalized(
  {region: "us-central1", memory: "512MiB"},
  async (event) => {
    const object = event.data;
    const path = object.name;
    const contentType = object.contentType ?? "";
    if (!path || !contentType.startsWith("image/")) {
      return;
    }
    const match = path.match(/^users\/([^/]+)\/profile\/(.+)$/);
    if (!match) {
      return;
    }

    const [, uid, fileName] = match;
    const bucket = storage.bucket(object.bucket);
    const [source] = await bucket.file(path).download();
    const teaser = await sharp(source)
      .rotate()
      .resize(72, 72, {fit: "cover"})
      .blur(24)
      .jpeg({quality: 35, mozjpeg: true})
      .toBuffer();

    await bucket.file(`profileTeasers/${uid}/${fileName}.jpg`).save(teaser, {
      contentType: "image/jpeg",
      metadata: {
        cacheControl: "public,max-age=3600",
      },
    });
  },
);
