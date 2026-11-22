(() => {
  const width = 128, height = 96;
  const smooth = (start, end, value) => {
    const t = Math.max(0, Math.min(1, (value - start) / (end - start)));
    return t * t * (3 - 2 * t);
  };
  const oval = (x, y, cx, cy, rx, ry, edge) => 1 - smooth(edge, 1, Math.hypot((x - cx) / rx, (y - cy) / ry));

  class PaintSurface {
    constructor(image, locks, feet, palette, save) {
      this.width = width;
      this.height = height;
      this.pixels = new Uint8Array(width * height);
      this.texture = new Uint8Array(width * height * 4);
      this.regions = new Int8Array(width * height).fill(-1);
      this.coverage = new Uint8Array(width * height);
      this.palette = palette;
      this.revision = 0;
      const initialize = () => {
        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        const ctx = canvas.getContext('2d', {willReadFrequently:true});
        ctx.drawImage(image, 0, 0, width, height);
        const data = ctx.getImageData(0, 0, width, height).data;
        for (let index = 0; index < this.pixels.length; index++) {
          const i = index * 4;
          if (data[i+3] < 100) continue;
          const x = (index % width + .5) / width, y = (Math.floor(index / width) + .5) / height;
          const luminance = (.30 * data[i] + .55 * data[i+1] + .15 * data[i+2]) / 255;
          const copper = smooth(.10,.25,(data[i]-data[i+1])/255) * smooth(.15,.39,(data[i]-data[i+2])/255);
          let best = .12;
          for (let region = 0; region < 4; region++) {
            const [hx,hy] = locks[region], [fx,fy] = feet[region];
            const hair = oval(x,y,hx,hy,region===3 ? .105 : .085,region===3 ? .30 : .16,.55) * copper;
            const hoof = oval(x,y,fx,fy+.018,.056,.039,.65) * (1-smooth(.68,.85,luminance));
            if (hair > best) { best = hair; this.regions[index] = region; }
            if (hoof > best) { best = hoof; this.regions[index] = region + 4; }
          }
          this.coverage[index] = this.regions[index] < 0 ? 0 : Math.round(best * 255);
        }
        if (!this.restore(save.paintLayer)) {
          const oldColors = [...(save.maneColors ?? Array(4).fill('')), ...(save.hoofColors ?? Array(4).fill(''))];
          const legacy = oldColors.map(hex => palette.findIndex(entry => entry[1] === hex) + 1);
          for (let idx = 0; idx < this.pixels.length; idx++) {
            const region = this.regions[idx], color = legacy[region];
            if (region >= 0 && color > 0 && color <= 6) {
              this.pixels[idx] = 0xf0 | color | (region >= 4 && save.hoofGlitter?.[region-4] ? 8 : 0);
            }
          }
        }
        for (let i = 0; i < this.pixels.length; i++) this.updateTexel(i);
        this.revision++;
        this.ready = true;
      };
      if (image.complete && image.naturalWidth) initialize();
      else image.addEventListener('load',initialize,{once:true});
    }

    restore(encoded) {
      if (!encoded) return false;
      try {
        const runs = atob(encoded);
        if (runs.length % 2 || runs.length > this.pixels.length * 2) return false;
        let end = 0;
        for (let i = 0; i < runs.length; i += 2) {
          const count = runs.charCodeAt(i), shade = runs.charCodeAt(i+1);
          if (!count || (shade & 7) > 6 || end + count > this.pixels.length) {
            this.pixels.fill(0);
            return false;
          }
          this.pixels.fill(shade,end,end+count);
          end += count;
        }
        if (end === this.pixels.length) return true;
      } catch {}
      this.pixels.fill(0);
      return false;
    }

    encode() {
      if (!this.ready || this.revision === this.encodedRevision) return this.encoded;
      let runs = '';
      for (let i = 0; i < this.pixels.length;) {
        const shade = this.pixels[i];
        let count = 1;
        while (count < 255 && i + count < this.pixels.length && this.pixels[i+count] === shade) count++;
        runs += String.fromCharCode(count,shade);
        i += count;
      }
      this.encodedRevision = this.revision;
      return this.encoded = btoa(runs);
    }

    updateTexel(index) {
      const shade = this.pixels[index], offset = index * 4, region = this.regions[index];
      this.texture[offset] = shade & 7;
      this.texture[offset+1] = +(region >= 4);
      this.texture[offset+2] = shade & 8 ? 255 : 0;
      this.texture[offset+3] = region < 0 ? 0 : Math.round(this.coverage[index] * (shade >> 4) / 15);
    }

    stroke(from, to, hair, pigment, glitter, only = -1) {
      if (!this.ready) return -1;
      let touched = -1;
      const radius = hair ? 4.9 : 3.4;
      const dx = (to[0]-from[0])*width, dy = (to[1]-from[1])*height;
      const steps = Math.max(1,Math.min(32,Math.ceil(Math.hypot(dx,dy)/1.7)));
      for (let step = 0; step < steps; step++) {
        const u = from[0]*width + dx*(step+1)/steps, v = from[1]*height + dy*(step+1)/steps;
        for (let y = Math.max(0,Math.floor(v-radius)); y < Math.min(height,v+radius); y++) {
          for (let x = Math.max(0,Math.floor(u-radius)); x < Math.min(width,u+radius); x++) {
            const index = y*width+x, region = this.regions[index];
            if (region < 0 || (region < 4) !== hair || (only >= 0 && only !== region % 4)) continue;
            const strength = Math.round(7*(1-smooth(.16,1,Math.hypot(x+.5-u,y+.5-v)/radius)));
            if (!strength) continue;
            const tag = pigment | (glitter && !hair && pigment ? 8 : 0), prior = this.pixels[index];
            const opacity = Math.min(15,strength + ((prior & 15) === tag ? prior >> 4 : 0));
            const next = opacity << 4 | tag;
            if (next === prior) continue;
            this.pixels[index] = next;
            this.updateTexel(index);
            touched = region % 4;
          }
        }
      }
      if (touched >= 0) this.revision++;
      return touched;
    }
  }
  window.PonyPaintSurface = PaintSurface;
})();
