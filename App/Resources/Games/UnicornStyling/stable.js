(() => {
  const root = document.getElementById('unicorn-stable');
  const art = Object.fromEntries(['pony', 'stall', 'brush', 'saddle', 'ribbon', 'comb', 'braid', 'curry'].map(name => [name, name + '.webp']));
  const bridge = window.webkit?.messageHandlers?.unicornStable;
  const calm = matchMedia('(prefers-reduced-motion: reduce)');
  const coat = [[.49,.53],[.53,.43],[.61,.49],[.69,.37]];
  const mane = [[.34,.55],[.32,.40],[.35,.26],[.85,.65]];
  const feet = [[.26,.91],[.35,.95],[.56,.92],[.70,.94]];
  const debris = [[.36,.40],[.64,.47],[.50,.68]];

  const colors = [
    ['Berry','#db5793'], ['Peach','#ee8763'], ['Gold','#efb943'],
    ['Mint','#57b68f'], ['Sky','#579fe6'], ['Lilac','#a56cd6'], ['Natural','']
  ];
  function rgb(hex) {
    return hex ? [1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)/255) : [0,0,0];
  }

  function paintInCanvas(canvas, image, motion) {
    const surface=canvas.cloneNode(false);
    canvas.replaceWith(surface);
    const context=surface.getContext('2d', {willReadFrequently:true});
    if(!context) { surface.hidden=true; image.style.visibility=''; return; }
    const smooth=(start,end,x)=>{
      const a=Math.max(0,Math.min(1,(x-start)/(end-start)));
      return a*a*(3-2*a);
    };
    const rim=(dx,dy,width,height,edge)=>1-smooth(edge,1,Math.hypot(dx/width,dy/height));
    function start() {
      const width=surface.width=Math.min(500,image.naturalWidth);
      const height=surface.height=Math.round(width*image.naturalHeight/image.naturalWidth);
      context.drawImage(image,0,0,width,height);
      const original=context.getImageData(0,0,width,height);
      const painted=context.createImageData(width,height);
      const areas=new Int8Array(width*height).fill(-1);
      const opacity=new Uint8Array(width*height);
      const luma=new Float32Array(width*height);
      const speckles=new Uint8Array(width*height);
      for(let y=0;y<height;y++) {
        for(let x=0;x<width;x++) {
          const i=y*width+x, offset=i*4;
          const [r,g,b]=[original.data[offset],original.data[offset+1],original.data[offset+2]];
          if(!original.data[offset+3]) continue;
          const u=x/width,v=y/height;
          const light=luma[i]=(.30*r+.55*g+.15*b)/255;
          const copper=smooth(.12,.26,(r-g)/255)*smooth(.16,.40,(r-b)/255);
          let best=0;
          for(let k=0;k<4;k++) {
            const hair=rim(u-mane[k][0],v-mane[k][1],k===3 ? .076 : .074,k===3 ? .248 : .132,.30)*copper*.88;
            const foot=rim(u-feet[k][0],v-feet[k][1]-.018,.051,.034,.59)*(1-smooth(.70,.88,light))*.98;
            if(hair>best) { best=hair; areas[i]=k; }
            if(foot>best) { best=foot; areas[i]=k+4; }
          }
          opacity[i]=Math.round(255*best);
          speckles[i]=((Math.imul(x+13,73856093)^Math.imul(y+17,19349663))>>>0)%100<6;
        }
      }
      image.style.visibility='hidden';
      motion.refresh=()=>{
        painted.data.set(original.data);
        for(let i=0;i<areas.length;i++) {
          const area=areas[i];
          if(area<0 || !opacity[i]) continue;
          const hoof=area>=4, index=area%4, offset=index*3, pixel=i*4;
          const palette=hoof?motion.hoofPaint:motion.manePaint;
          if(!palette[offset]&&!palette[offset+1]&&!palette[offset+2]) continue;
          const light=luma[i], amount=opacity[i]/255, shine=hoof&&speckles[i]&&motion.sparkle[index] ? .78 : 0;
          for(let c=0;c<3;c++) {
            const tone=hoof ? palette[offset+c]*(.48+light*.79)+.08*light
              : palette[offset+c]*(.45+light*.82)+Math.max(0,light-.53)*.43;
            const tint=tone*(1-shine)+[1,.94,.68][c]*shine;
            painted.data[pixel+c]=original.data[pixel+c]*(1-amount)+tint*255*amount;
          }
        }
        context.putImageData(painted,0,0);
      };
      surface.dataset.renderer='canvas';
      motion.refresh();
    }
    if(image.complete&&image.naturalWidth) start();
    else image.addEventListener('load',start,{once:true});
  }

  function paintPony(canvas, image, motion) {
    const gl = canvas.getContext('webgl', { alpha: true });
    if (!gl) { paintInCanvas(canvas,image,motion); return; }
    function shader(kind, code) {
      const object = gl.createShader(kind);
      gl.shaderSource(object, code);
      gl.compileShader(object);
      return object;
    }
    const program = gl.createProgram();
    gl.attachShader(program, shader(gl.VERTEX_SHADER, `
      attribute vec2 uv;
      uniform float t, touch, lift, quiet;
      varying vec2 tex;
      void main() {
        tex = uv;
        vec2 p = uv;
        float head = (1.0-smoothstep(.18,.43,p.x)) * (1.0-smoothstep(.26,.62,p.y));
        float mane = smoothstep(.26,.36,p.x) * (1.0-smoothstep(.43,.54,p.x)) * smoothstep(.22,.64,p.y);
        float tail = smoothstep(.72,.94,p.x) * smoothstep(.32,.92,p.y);
        float mid = smoothstep(.33,.53,p.x) * (1.0-smoothstep(.68,.79,p.x));
        float bent = (1.0-smoothstep(.031,.058,abs(p.x-lift))) * smoothstep(.61,.95,p.y);
        float ear = (1.0-smoothstep(.025,.052,abs(p.x-.185))) * (1.0-smoothstep(.025,.14,p.y));
        p.x += bent*.023 + quiet * (head * sin(t*1.25)*.007 + mane*(sin(t*2.6+p.y*5.0)*.008 + touch*.021)
          + tail*sin(t*2.05+p.y*3.0)*.019 + ear*sin(t*4.5)*.006);
        p.y += -bent*.081 + quiet * (head*(sin(t*1.25)*.006 + touch*.017) - mid*sin(t*2.2)*.005);
        gl_Position = vec4(2.0*p.x-1.0,1.0-2.0*p.y,0,1);
      }`));
    gl.attachShader(program, shader(gl.FRAGMENT_SHADER, `
      precision mediump float;
      varying vec2 tex;
      uniform sampler2D paint;
      uniform vec2 hairSites[4], footSites[4];
      uniform vec3 manePaint[4], hoofPaint[4];
      uniform float sparkle[4];
      float rim(vec2 center, vec2 width, float start) {
        return 1.0-smoothstep(start,1.0,length((tex-center)/width));
      }
      void main() {
        vec4 base = texture2D(paint, tex);
        if (base.a < .001) { gl_FragColor=base; return; }
        vec3 original = base.rgb / base.a;
        float luminance = dot(original,vec3(.30,.55,.15));
        float copper = smoothstep(.12,.26,original.r-original.g) * smoothstep(.16,.40,original.r-original.b);
        vec3 coat = original;
        for(int i=0;i<4;i++) {
          vec2 center=hairSites[i];
          vec2 width=i==3 ? vec2(.076,.248) : vec2(.074,.132);
          float hair=rim(center,width,.30)*copper*step(.05,length(manePaint[i]));
          vec3 tint=manePaint[i]*(.45+luminance*.82)+vec3(max(0.0,luminance-.53)*.43);
          coat=mix(coat,tint,hair*.88);
          float nail=rim(footSites[i]+vec2(.0,.018),vec2(.051,.034),.59)
            *(1.0-smoothstep(.70,.88,luminance))*step(.05,length(hoofPaint[i]));
          vec3 polish=hoofPaint[i]*(.48+luminance*.79)+vec3(.08)*luminance;
          vec2 grain=floor(tex*vec2(325.0,255.0));
          float seed=fract(sin(dot(grain,vec2(12.9898,78.233)))*137.123);
          polish=mix(polish,vec3(1.0,.94,.68),step(.935,seed)*sparkle[i]*.78);
          coat=mix(coat,polish,nail*.98);
        }
        gl_FragColor=vec4(coat*base.a,base.a);
      }`));
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) { paintInCanvas(canvas,image,motion); return; }
    gl.useProgram(program);
    const vertices = [];
    for (let j = 0; j < 14; j++) {
      for (let i = 0; i < 24; i++) {
        const x = i/24, y = j/14, a = (i+1)/24, b = (j+1)/14;
        vertices.push(x,y, a,y, x,b, x,b, a,y, a,b);
      }
    }
    gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW);
    const uv = gl.getAttribLocation(program, 'uv');
    gl.enableVertexAttribArray(uv);
    gl.vertexAttribPointer(uv, 2, gl.FLOAT, false, 0, 0);
    const uniforms = Object.fromEntries(['t','touch','lift','quiet'].map(k => [k, gl.getUniformLocation(program,k)]));
    const paintUniforms = Object.fromEntries(['hairSites','footSites','manePaint','hoofPaint','sparkle'].map(
      name=>[name,gl.getUniformLocation(program,name+'[0]')]));
    gl.uniform2fv(paintUniforms.hairSites,new Float32Array(mane.flat()));
    gl.uniform2fv(paintUniforms.footSites,new Float32Array(feet.flat()));
    gl.bindTexture(gl.TEXTURE_2D, gl.createTexture());
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    function start() {
      gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, true);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
      image.style.visibility = 'hidden';
      canvas.dataset.renderer='webgl';
      let frame = 0;
      function tick(now) {
        requestAnimationFrame(tick);
        if (now-frame < 32 || !canvas.clientWidth || document.hidden) return;
        frame = now;
        const dpr = Math.min(devicePixelRatio, 2);
        const w = Math.round(canvas.clientWidth * dpr), h = Math.round(canvas.clientHeight * dpr);
        if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
        gl.viewport(0, 0, w, h);
        gl.clear(gl.COLOR_BUFFER_BIT);
        gl.uniform1f(uniforms.t, now / 1000);
        gl.uniform1f(uniforms.touch, Math.max(0, (motion.touch - now) / 650));
        gl.uniform1f(uniforms.lift, motion.lift);
        gl.uniform1f(uniforms.quiet, +!calm.matches);
        gl.uniform3fv(paintUniforms.manePaint,motion.manePaint);
        gl.uniform3fv(paintUniforms.hoofPaint,motion.hoofPaint);
        gl.uniform1fv(paintUniforms.sparkle,motion.sparkle);
        gl.drawArrays(gl.TRIANGLES, 0, vertices.length / 2);
      }
      requestAnimationFrame(tick);
    }
    if (image.complete && image.naturalWidth) start();
    else image.addEventListener('load', start, { once: true });
    canvas.addEventListener('webglcontextlost', () => paintInCanvas(canvas,image,motion), {once:true});
  }

  function init(panel) {
    const find = s => panel.querySelector(s);
    const game = find('.stable-game'), actor = find('.stable-pony'), targets = find('.stable-targets');
    const image = find('.stable-art'), brush = find('.stable-brush'), effects = find('.stable-effect');
    const status = find('.stable-sign small'), hint = find('.stable-hint');
    const hoof = find('.stable-hoof'), chips = find('.hoof-chips');
    const stations = find('.stable-stations'), tools = find('.stable-tools'), swatches=find('.stable-colors');
    const saddle = find('.stable-saddle'), pad = find('.stable-pad'), ribbon = find('.stable-ribbon'), braid = find('.stable-braid');
    const secondBraid=find('.second-braid'), motif=find('.pad-motif');
    const motion = { touch: 0, lift: -1, manePaint:new Float32Array(12), hoofPaint:new Float32Array(12), sparkle:new Float32Array(4) };
    const save = window.glimmieStableSave ?? {};
    const maneColors = save.maneColors ?? Array(4).fill('');
    const hoofColors = save.hoofColors ?? Array(4).fill('');
    const packed = save.packed ?? [1,0,0,1], brushed = save.brushed ?? [0,0,0,0];
    const sole = save.soles ?? feet.map(() => [1,1,1]);
    const strandSites = [[.29,.31],[.41,.39],[.29,.47],[.40,.54]];
    const padSpots=[[.60,.39],[.614,.478],[.549,.504]], padMarks=save.padMarks ?? ['','',''];
    let station = 'Mane', coatTool = 'Curry comb', hoofTool = 'Hoof pick', maneMode='Color', hoofMode='Paint';
    let maneStep = save.maneStep ?? 0, maneProgress = save.maneProgress ?? 0, lifted = -1;
    let braidStyle = save.braidStyle ?? 0, crossed = save.crossed ?? 0, braidMode = crossed < braidStyle*2;
    let tone=0, glitter=false, stampChoice=null;
    let padColor = save.padColor ?? '', hasSaddle = save.hasSaddle ?? false, girth = save.girth ?? 0;
    let bow = save.bow ?? '', scratched = save.scratched ?? false;
    let gesture = null, hoofGesture = null;

    maneColors.forEach((color,i)=>motion.manePaint.set(rgb(color),i*3));
    hoofColors.forEach((color,i)=>motion.hoofPaint.set(rgb(color),i*3));
    if (save.hoofGlitter) motion.sparkle.set(save.hoofGlitter.map(Number));
    function snapshot() {
      return JSON.stringify({
        packed, brushed, soles:sole, maneStep, maneProgress, braidStyle, crossed, maneColors, hoofColors,
        hoofGlitter:Array.from(motion.sparkle, Boolean), padColor, hasSaddle, girth, bow, padMarks, scratched
      });
    }
    let sent=snapshot();
    function persist() {
      const value=snapshot();
      if(value===sent) return;
      sent=value;
      bridge?.postMessage({kind:'save',value});
    }

    find('.stable-sign strong').textContent = 'Unicorn Stable';
    find('.stable-setting').src = art.stall;
    image.src = window.glimmiePonyTexture ?? art.pony;
    saddle.src = art.saddle;
    ribbon.src = art.ribbon;
    if (art.braid) braid.src = secondBraid.src = art.braid;
    paintPony(find('canvas'), image, motion);

    function tool(label, action, options = {}) {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'stable-tool cursor-interaction';
      if (options.art && art[options.art]) {
        const icon = document.createElement('img');
        icon.src = art[options.art]; icon.alt = ''; button.append(icon);
      }
      const name = document.createElement('span');
      name.textContent = label;
      button.append(name);
      if ('selected' in options) button.setAttribute('aria-pressed', options.selected);
      if (options.disabled) button.disabled = true;
      button.addEventListener('click', action);
      return button;
    }

    function mark(parent, point, className, label, action, cue) {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = className + ' cursor-interaction';
      button.setAttribute('aria-label', label);
      button.style.left = point[0]*100 + '%';
      button.style.top = point[1]*100 + '%';
      if (cue) button.dataset.cue = cue;
      button.addEventListener('click', action);
      parent.append(button);
      return button;
    }

    function swatch(label, color, action, selected=false, shape='', mark='') {
      const button=document.createElement('button');
      button.type='button';
      button.className='studio-swatch cursor-interaction '+shape;
      button.setAttribute('aria-label',label);
      button.setAttribute('aria-pressed',selected);
      button.style.setProperty('--swatch',color||'#e5ceb2');
      const chip=document.createElement('span');
      chip.setAttribute('aria-hidden','true');
      chip.textContent=mark;
      button.append(chip);
      button.addEventListener('click',action);
      return button;
    }

    function palette() {
      swatches.hidden=false;
      for(let i=0;i<colors.length;i++) {
        const [name,hex]=colors[i];
        swatches.append(swatch(name,hex,()=>{ tone=i; render(); },tone===i,'',hex?'':'↶'));
      }
    }

    function paintAt(i, hair) {
      const hex=colors[tone][1], surface=hair?maneColors:hoofColors;
      const spark=!hair && glitter && !!hex;
      if(surface[i]===hex && (hair||motion.sparkle[i]===+spark)) return;
      surface[i]=hex;
      const points=hair?mane:feet, pigment=hair?motion.manePaint:motion.hoofPaint;
      pigment.set(rgb(hex),i*3);
      if(!hair) motion.sparkle[i]=+spark;
      motion.refresh?.();
      feedback(points[i]);
      render();
    }

    function feedback(point) {
      motion.touch = performance.now() + 650;
      bridge?.postMessage({kind:'sparkle'});
      if (!point || calm.matches) return;
      [-12, 7, 19].forEach((dx,i) => {
        const light = document.createElement('span');
        light.textContent = i === 1 ? '✦' : '·';
        light.style.left = (point[0]*100+i*2-1) + '%';
        light.style.top = (point[1]*100) + '%';
        light.style.setProperty('--glint-x',dx+'px');
        light.addEventListener('animationend', () => light.remove(), {once:true});
        effects.append(light);
      });
    }

    const countClean = () => brushed.filter(value=>value>=1).length;
    const countHooves = () => sole.filter(hoof=>hoof.every(value=>value<=0)).length;
    const isReady = () => countClean() === coat.length && maneStep === mane.length && countHooves() === feet.length;
    const text = message => { if (hint.textContent !== message) hint.textContent = message; };
    function clearLift() { lifted = -1; motion.lift = -1; }

    function affectCoat(i, amount) {
      if (brushed[i]>=1) return;
      if (padColor && i<3) {
        text('Take off the saddle pad to reach the coat underneath.');
        return;
      }
      const node = targets.querySelector('[data-dust="'+i+'"]');
      if (coatTool === 'Curry comb' && packed[i]>0) {
        packed[i] = Math.max(0,packed[i]-amount);
        if (!packed[i]) { feedback(coat[i]); render(); }
        else node?.style.setProperty('--remaining',.57+packed[i]*.43);
      } else if (coatTool === 'Soft brush' && !packed[i]) {
        brushed[i] = Math.min(1,brushed[i]+amount);
        if (brushed[i]===1) { feedback(coat[i]); render(); }
        else node?.style.setProperty('--remaining',1-brushed[i]);
      }
    }

    function comb(amount) {
      if (maneStep>=mane.length) return;
      maneProgress += amount;
      if (maneProgress>=1) {
        feedback(mane[maneStep]);
        maneStep++; maneProgress=0;
        render();
      } else {
        const node=targets.querySelector('.active-knot');
        if (node) node.style.opacity=1-.46*maneProgress;
      }
    }

    function cross() {
      const goal=braidStyle*2;
      if (!braidMode || crossed>=goal) return;
      feedback(strandSites[crossed]);
      crossed++;
      if (crossed===goal) braidMode=false;
      render();
    }

    function chooseBraid(count) {
      braidStyle=count;
      crossed=0;
      braidMode=count>0;
      render();
    }

    function clearDebris(i, amount) {
      if (lifted<0 || sole[lifted][i]<=0) return;
      if ((i===2 && hoofTool!=='Hoof brush') || (i!==2 && hoofTool!=='Hoof pick')) {
        text(i===2 ? 'Brush the loose straw out of the groove.' : 'Use the hoof pick for pebbles.');
        return;
      }
      sole[lifted][i]=Math.max(0,sole[lifted][i]-amount);
      if (sole[lifted][i]===0) {
        feedback(feet[lifted]); render();
      } else chips.querySelector('[data-chip="'+i+'"]')?.style.setProperty('--remaining',sole[lifted][i]);
    }

    function renderCoat() {
      tools.append(
        tool('Curry comb',()=>{ coatTool='Curry comb'; render(); },{selected:coatTool==='Curry comb',art:'curry'}),
        tool('Soft brush',()=>{ coatTool='Soft brush'; render(); },{selected:coatTool==='Soft brush',art:'brush'})
      );
      if (padColor) tools.append(tool('Remove tack',()=>setPad(padColor)));
      coat.forEach((point,i)=>{
        if (brushed[i]>=1) return;
        const stamp=mark(targets,point,'stable-dot dust'+(packed[i]?' packed':''),
          packed[i]?'Loosen dried mud '+(i+1):'Brush loose dirt '+(i+1),()=>{
            if (packed[i] && coatTool==='Soft brush') return text('Loosen this patch with the curry comb first.');
            if (!packed[i] && coatTool==='Curry comb') return text('This dirt is loose. Switch to the soft brush.');
            affectCoat(i,.35);
          });
        stamp.dataset.dust=i;
        stamp.style.setProperty('--remaining',packed[i] ? .57+packed[i]*.43 : 1-brushed[i]);
      });
      status.textContent=countClean()+' of '+coat.length+' patches clean';
      if (countClean()===coat.length) text('The coat is clean and glossy.');
      else if (coatTool==='Curry comb') text(packed.some(v=>v>0) ? 'Circle over the darker mud with the curry comb.' : 'The mud is loose. Switch to the soft brush.');
      else text('Sweep the loose dirt toward the tail.');
    }

    function renderMane() {
      for(const label of ['Color','Braid','Comb']) {
        tools.append(tool(label,()=>{ maneMode=label; render(); },{selected:maneMode===label,art:label==='Comb'?'comb':null}));
      }
      if(maneMode==='Color') {
        status.textContent='Mane colors';
        palette();
        const labels=['Mane ends','Middle mane','Upper mane','Tail'];
        mane.forEach((point,i)=>{
          const target=mark(targets,point,'stable-dot paint-mark','Color '+labels[i],()=>paintAt(i,true));
          target.style.setProperty('--mark-color',maneColors[i]||'#f6ecd988');
        });
        text(colors[tone][1]?'Tap or sweep over a lock to add '+colors[tone][0]+'.':'Tap a lock to bring back its natural color.');
      } else if(maneMode==='Comb' && maneStep<mane.length) {
        status.textContent='Comb the mane';
        mark(targets,mane[maneStep],'stable-dot active-knot','Comb this tangle',()=>comb(.35));
        text(maneStep===mane.length-1?'Comb down through the tail tangle.':'Comb down through the highlighted lock. Start near the ends.');
      } else if(maneMode==='Comb') {
        status.textContent='Mane combed';
        text('Her mane and tail are smooth.');
      } else {
        status.textContent=braidMode?'Weave the mane':crossed?'Mane braided':'Braids';
        tools.append(tool('One braid',()=>chooseBraid(1),{selected:braidStyle===1}),
          tool('Two braids',()=>chooseBraid(2),{selected:braidStyle===2}),
          tool('Loose mane',()=>chooseBraid(0),{selected:braidStyle===0}));
        if(braidMode) {
          const side=crossed%2===0?'left':'right';
          mark(targets,strandSites[crossed],'stable-dot target-arrow','Cross '+side+' strand',cross,side==='left'?'→':'←');
          text('Tap the strand or pull it across the center.');
        } else text(crossed?'The braid is in place. You can color it or add a ribbon.':'Pick a braid to get started.');
      }
    }

    function renderHooves() {
      tools.append(tool('Paint',()=>{ hoofMode='Paint'; clearLift(); render(); },{selected:hoofMode==='Paint'}),
        tool('Clean',()=>{ hoofMode='Clean'; clearLift(); render(); },{selected:hoofMode==='Clean'}));
      if(hoofMode==='Paint') {
        status.textContent='Hoof colors';
        palette();
        tools.append(tool('Glitter',()=>{ glitter=!glitter; render(); },{selected:glitter}));
        const hooves=document.createElement('div');
        hooves.className='hoof-choices';
        hooves.setAttribute('role','group');
        hooves.setAttribute('aria-label','Paint each hoof');
        tools.append(hooves);
        feet.forEach((point,i)=>{
          const name='Paint hoof '+(i+1);
          hooves.append(swatch(name,hoofColors[i]||'#a47d62',()=>paintAt(i,false),false,'hoof-tile',motion.sparkle[i]?'✦':(i+1)));
          const target=mark(targets,point,'stable-dot paint-mark','Paint on pony hoof '+(i+1),()=>paintAt(i,false));
          target.style.setProperty('--mark-color',hoofColors[i]||'#f6ecd988');
        });
        text(colors[tone][1]?'Pick a color and tap a hoof. Mix colors however you like.':'Tap a hoof to wash off its color.');
        return;
      }
      status.textContent=countHooves()+' of '+feet.length+' hooves clean';
      if (lifted<0) {
        feet.forEach((point,i)=>mark(targets,point,'stable-dot'+(sole[i].every(v=>v===0)?' target-arrow':''),
          'Lift hoof '+(i+1),()=>{ lifted=i; motion.lift=point[0]; hoofTool='Hoof pick'; render(); },
          sole[i].every(v=>v===0)?'✓':''));
        text('Tap a hoof to lift it.');
        return;
      }
      debris.forEach((point,i)=>{
        if (sole[lifted][i]<=0) return;
        const node=mark(chips,point,'hoof-chip'+(i===2?' hoof-chaff':''),
          i===2?'Brush loose straw':'Pick pebble '+(i+1),()=>clearDebris(i,i===2?.35:1));
        node.dataset.chip=i;
        node.style.setProperty('--remaining',sole[lifted][i]);
      });
      tools.append(tool('Hoof pick',()=>{ hoofTool='Hoof pick'; render(); },{selected:hoofTool==='Hoof pick'}),
        tool('Hoof brush',()=>{ hoofTool='Hoof brush'; render(); },{selected:hoofTool==='Hoof brush'}),
        tool('Lower hoof',()=>{ clearLift(); render(); }));
      text(sole[lifted].every(v=>v<=0) ? 'This hoof is clean. Lower it when you’re ready.'
        : hoofTool==='Hoof pick' ? 'Flick the pebbles away from the middle.' : 'Sweep the loose straw out of the groove.');
    }

    function setPad(color) {
      padColor=padColor===color ? '' : color;
      if (!padColor) { hasSaddle=false; girth=0; }
      render();
    }

    function renderTack() {
      status.textContent=hasSaddle ? (girth===3?'Saddle fitted':'Girth needs adjusting') : 'Tack fitting';
      tools.append(tool('Mint pad',()=>setPad('mint'),{selected:padColor==='mint'}),
        tool('Lilac pad',()=>setPad('lilac'),{selected:padColor==='lilac'}),
        tool('Saddle',()=>{ hasSaddle=!hasSaddle; girth=0; render(); },{selected:hasSaddle,disabled:!padColor}),
        tool('Lilac ribbon',()=>{ bow=bow==='lilac'?'':'lilac'; render(); },{selected:bow==='lilac'}),
        tool('Rose ribbon',()=>{ bow=bow==='rose'?'':'rose'; render(); },{selected:bow==='rose'}));
      if(padColor) {
        for(const [label,shape] of [['Star stamp','✦'],['Heart stamp','♥'],['Erase stamp','']]) {
          tools.append(tool(label,()=>{ stampChoice=stampChoice===shape?null:shape; render(); },{selected:stampChoice===shape}));
        }
        if(stampChoice!==null) {
          swatches.hidden=false;
          padSpots.forEach((point,i)=>{
            const place=()=>{ padMarks[i]=stampChoice; feedback(point); render(); };
            mark(targets,point,'stable-dot paint-mark','Place stamp on pad '+(i+1),place);
            swatches.append(swatch('Stamp spot '+(i+1),'#dcc4e8',place,false,'',padMarks[i]||(i+1)));
          });
        }
      }
      if (hasSaddle) {
        const label=document.createElement('label'), slider=document.createElement('input'), readout=document.createElement('span');
        label.className='girth-control';
        label.textContent='Girth';
        slider.type='range'; slider.min='0'; slider.max='5'; slider.step='1'; slider.value=girth;
        function fit() {
          const words=girth===3?'Snug':girth>3?'Too tight':'Loose';
          readout.textContent=words;
          slider.setAttribute('aria-valuetext',words);
          pad.style.setProperty('--girth-turn',(girth-3)*3+'deg');
          status.textContent=girth===3?'Saddle fitted':'Girth needs adjusting';
          text(girth===3?'Saddle and pad are set.':'Adjust the girth until it reads snug.');
        }
        slider.addEventListener('input',()=>{ girth=Number(slider.value); fit(); });
        slider.addEventListener('change',()=>{ persist(); if (girth===3) feedback([.50,.48]); });
        label.append(slider,readout); tools.append(label); fit();
      } else {
        text(padColor?'Place the saddle over the pad, or tie on a ribbon.':'Choose a saddle pad or tie on a ribbon.');
      }
      if(padColor && stampChoice!==null) text(stampChoice?'Tap the pad or a numbered spot to stamp it.':'Tap a spot to erase its stamp.');
    }

    function render() {
      targets.replaceChildren(); chips.replaceChildren(); tools.replaceChildren(); stations.replaceChildren(); swatches.replaceChildren();
      swatches.hidden=true;
      hoof.hidden=lifted<0;
      game.classList.toggle('is-hoof',lifted>=0);
      game.classList.toggle('is-mane',station==='Mane');
      pad.hidden=!padColor; saddle.hidden=!hasSaddle; ribbon.hidden=!bow;
      braid.hidden=!(art.braid && crossed>=2);
      secondBraid.hidden=!(art.braid && crossed>=4);
      const braidHue=['48deg','0deg','-21deg','100deg','185deg','245deg'];
      const hueFor=color=>color?'hue-rotate('+braidHue[colors.findIndex(entry=>entry[1]===color)]+') saturate(.72)':'';
      braid.style.filter=hueFor(maneColors[0]||maneColors[1]);
      secondBraid.style.filter=hueFor(maneColors[2]||maneColors[1]);
      motif.hidden=!padColor || !padMarks.some(Boolean);
      motif.replaceChildren();
      for(let i=0;i<padMarks.length;i++) {
        if(!padMarks[i]) continue;
        const patch=document.createElement('span');
        patch.style.left=padSpots[i][0]*100+'%';
        patch.style.top=padSpots[i][1]*100+'%';
        patch.textContent=padMarks[i];
        motif.append(patch);
      }
      pad.style.setProperty('--pad',padColor==='lilac'?'#ae91c0':'#8fb9a1');
      pad.style.setProperty('--pad-border',padColor==='lilac'?'#dec9e8':'#c4e0b9');
      pad.classList.toggle('has-saddle',hasSaddle);
      saddle.style.filter=padColor==='lilac'?'hue-rotate(7deg)':'';
      ribbon.style.filter=bow==='rose'?'hue-rotate(44deg) saturate(1.14)':'';
      ribbon.style.left=crossed>=2?'29%':'76%';
      ribbon.style.top=crossed>=2?'54%':'36%';
      for (const label of ['Coat','Mane','Hooves','Tack']) {
        stations.append(tool(label,()=>{
          station=label; clearLift(); brush.hidden=true; render();
        },{selected:station===label}));
      }
      switch(station) {
        case 'Coat': renderCoat(); break;
        case 'Mane': renderMane(); break;
        case 'Hooves': renderHooves(); break;
        case 'Tack': renderTack(); break;
      }
      if (isReady() && !scratched) {
        tools.append(tool('Give a scratch',()=>{
          scratched=true; feedback([.21,.16]); render(); text('She leans into the scratch.');
        }));
      }
      persist();
    }

    function at(event, element) {
      const box=element.getBoundingClientRect();
      return [(event.clientX-box.left)/box.width,(event.clientY-box.top)/box.height];
    }
    const close=(a,b,x,y)=>Math.hypot((a[0]-b[0])/x,(a[1]-b[1])/y)<=1;
    actor.addEventListener('pointerdown',event=>{
      if (station==='Coat'||station==='Mane'||(station==='Hooves'&&hoofMode==='Paint')) {
        gesture={id:event.pointerId,point:at(event,actor)};
      }
    });
    actor.addEventListener('pointermove',event=>{
      if (!gesture||event.pointerId!==gesture.id) return;
      const p=at(event,actor), q=gesture.point;
      const dx=p[0]-q[0], dy=p[1]-q[1];
      if (Math.hypot(dx,dy)<.008) return;
      if (!actor.hasPointerCapture(event.pointerId)) actor.setPointerCapture(event.pointerId);
      gesture.point=p;
      const middle=[(p[0]+q[0])/2,(p[1]+q[1])/2];
      if ((station==='Mane'&&maneMode==='Color') || station==='Hooves') {
        const hair=station==='Mane', points=hair?mane:feet;
        const closest=points.reduce((best, point,i)=>{
          const distance=Math.hypot(p[0]-point[0],p[1]-point[1]);
          return distance<best.distance?{i,distance}:best;
        },{i:-1,distance:hair ? .104 : .064});
        if(closest.i>=0) paintAt(closest.i,hair);
        return;
      }
      if (station==='Coat'||maneMode==='Comb') {
        brush.hidden=false;
        const toolName=station==='Mane'?'comb':coatTool==='Curry comb'?'curry':'brush';
        brush.src=art[toolName]||art.brush;
        brush.style.left=p[0]*100+'%'; brush.style.top=p[1]*100+'%';
      }
      if(station==='Coat') {
        coat.forEach((center,i)=>{
          if(!close(middle,center,.093,.092)) return;
          if(coatTool==='Soft brush' && dx>.004 && Math.abs(dy)<dx*1.7) {
            affectCoat(i,Math.min(.31,dx*7));
          } else if(coatTool==='Curry comb') {
            const a=Math.atan2(q[1]-center[1],q[0]-center[0]);
            const b=Math.atan2(p[1]-center[1],p[0]-center[0]);
            const arc=Math.atan2(Math.sin(b-a),Math.cos(b-a));
            if(Math.abs(arc)<1.15) affectCoat(i,Math.min(.20,Math.abs(arc)*.166));
          }
        });
      } else if(maneMode==='Braid'&&braidMode) {
        const from=strandSites[crossed], towardsCenter=crossed%2===0 ? p[0]>.345 : p[0]<.345;
        if(close(q,from,.11,.12) && towardsCenter && Math.abs(dx)>.018) cross();
      } else if(maneMode==='Comb'&&maneStep<mane.length && dy>.004 && Math.abs(dx)<dy*1.55 &&
        close(middle,mane[maneStep],.10,.14)) comb(Math.min(.38,dy*8.2));
    });
    for(const eventName of ['pointerup','pointercancel','lostpointercapture']) {
      actor.addEventListener(eventName,event=>{
        if(gesture?.id===event.pointerId) { gesture=null; brush.hidden=true; persist(); }
      });
      chips.addEventListener(eventName,()=>{ hoofGesture=null; persist(); });
    }
    chips.addEventListener('pointerdown',event=>{
      const chip=event.target.closest('[data-chip]');
      if(chip) hoofGesture={id:event.pointerId,i:Number(chip.dataset.chip),point:at(event,chips)};
    });
    chips.addEventListener('pointermove',event=>{
      if(!hoofGesture||event.pointerId!==hoofGesture.id) return;
      const p=at(event,chips), q=hoofGesture.point, i=hoofGesture.i;
      const outward=(p[0]-q[0])*(q[0]-.50)+(p[1]-q[1])*(q[1]-.46);
      if(i!==2 && outward>.013) {
        hoofGesture=null; chips.setPointerCapture(event.pointerId); clearDebris(i,1);
      } else if(i===2 && Math.abs(p[0]-q[0])>.03 && Math.abs(p[1]-q[1])<.13) {
        hoofGesture.point=p;
        if(!chips.hasPointerCapture(event.pointerId)) chips.setPointerCapture(event.pointerId);
        clearDebris(i,Math.min(.36,Math.abs(p[0]-q[0])*5));
      }
    });
    document.addEventListener('visibilitychange',()=>{ if(document.hidden) persist(); });
    render();
  }
  init(root);
})();
