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
    function start() {
      const width=surface.width=Math.min(500,image.naturalWidth);
      const height=surface.height=Math.round(width*image.naturalHeight/image.naturalWidth);
      context.drawImage(image,0,0,width,height);
      const original=context.getImageData(0,0,width,height);
      const painted=context.createImageData(width,height);
      const paint=motion.paint;
      const palette=colors.map(entry=>rgb(entry[1]));
      image.style.visibility='hidden';
      motion.refresh=()=>{
        painted.data.set(original.data);
        for(let y=0;y<height;y++) {
          for(let x=0;x<width;x++) {
            const color=(Math.floor(y*paint.height/height)*paint.width+Math.floor(x*paint.width/width))*4;
            const pigment=paint.texture[color], amount=paint.texture[color+3]/255;
            if(!pigment || !amount) continue;
            const i=(y*width+x)*4, hoof=paint.texture[color+1];
            const light=(.30*original.data[i]+.55*original.data[i+1]+.15*original.data[i+2])/255;
            const glitter=paint.texture[color+2] && ((Math.imul(x+13,73856093)^Math.imul(y+17,19349663))>>>0)%100<6;
            for(let c=0;c<3;c++) {
              const tint=hoof ? palette[pigment-1][c]*(.48+light*.79)+.08*light
                : palette[pigment-1][c]*(.45+light*.82)+Math.max(0,light-.53)*.43;
              const shade=glitter ? tint*.22+[1,.94,.68][c]*.78 : tint;
              painted.data[i+c]=original.data[i+c]*(1-amount)+shade*255*amount;
            }
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
      uniform vec2 contact, pull;
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
        float reach=1.0-smoothstep(.015,.19,length((uv-contact)*vec2(1.0,.78)));
        float strands=max(mane,tail);
        p += pull * reach * max(strands*1.45, .12);
        p.x += bent*.023 + quiet * (head * sin(t*1.25)*.007 + mane*sin(t*2.6+p.y*5.0)*.008
          + tail*sin(t*2.05+p.y*3.0)*.019 + ear*sin(t*4.5)*.006);
        p.y += -bent*.081 + quiet * (head*(sin(t*1.25)*.006 + touch*.017) - mid*sin(t*2.2)*.005);
        gl_Position = vec4(2.0*p.x-1.0,1.0-2.0*p.y,0,1);
      }`));
    gl.attachShader(program, shader(gl.FRAGMENT_SHADER, `
      precision highp float;
      varying vec2 tex;
      uniform sampler2D paint, strokes;
      uniform vec3 palette[7];
      vec3 layer(vec2 pos, vec3 original, float light, float seed) {
        vec4 dab=texture2D(strokes,pos);
        int pigment=int(floor(dab.r*255.0+.5));
        if(pigment==0) return original;
        vec3 color=vec3(0.0);
        for(int i=1;i<7;i++) {
          if(pigment==i) color=palette[i];
        }
        vec3 hair=color*(.45+light*.82)+vec3(max(0.0,light-.53)*.43);
        vec3 hoof=color*(.48+light*.79)+vec3(.08)*light;
        hoof=mix(hoof,vec3(1.0,.94,.68),step(.935,seed)*dab.b*.78);
        return mix(original,mix(hair,hoof,step(.002,dab.g)),dab.a);
      }
      void main() {
        vec4 base = texture2D(paint, tex);
        if (base.a < .001) { gl_FragColor=base; return; }
        vec3 original = base.rgb / base.a;
        float luminance = dot(original,vec3(.30,.55,.15));
        vec2 grain=floor(tex*vec2(325.0,255.0));
        float seed=fract(sin(dot(grain,vec2(12.9898,78.233)))*137.123);
        vec2 count=vec2(128.0,96.0), cell=tex*count-.5;
        vec2 origin=(floor(cell)+.5)/count, blend=fract(cell), offset=1.0/count;
        vec3 top=mix(layer(origin,original,luminance,seed),layer(origin+vec2(offset.x,0.0),original,luminance,seed),blend.x);
        vec3 bottom=mix(layer(origin+vec2(0.0,offset.y),original,luminance,seed),layer(origin+offset,original,luminance,seed),blend.x);
        vec3 coat=mix(top,bottom,blend.y);
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
    const uniforms = Object.fromEntries(['t','touch','lift','quiet','contact','pull'].map(k => [k, gl.getUniformLocation(program,k)]));
    gl.uniform3fv(gl.getUniformLocation(program,'palette[0]'),new Float32Array([0,0,0,...colors.slice(0,6).flatMap(entry=>rgb(entry[1]))]));
    gl.uniform1i(gl.getUniformLocation(program,'strokes'),1);
    gl.bindTexture(gl.TEXTURE_2D, gl.createTexture());
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    function start() {
      gl.pixelStorei(gl.UNPACK_PREMULTIPLY_ALPHA_WEBGL, true);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, image);
      gl.activeTexture(gl.TEXTURE1);
      gl.bindTexture(gl.TEXTURE_2D,gl.createTexture());
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.NEAREST);
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.NEAREST);
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
      image.style.visibility = 'hidden';
      canvas.dataset.renderer='webgl';
      let frame = 0, revision = -1;
      function tick(now) {
        if(!canvas.isConnected) return;
        requestAnimationFrame(tick);
        if (now-frame < (motion.held ? 15 : 32) || !canvas.clientWidth || document.hidden) return;
        const delta=Math.min(.05,(now-frame)/1000);
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
        for(let i=0;i<2;i++) {
          const target=motion.held?motion.drag[i]:0;
          motion.velocity[i]+=(target-motion.pull[i])*delta*180;
          motion.velocity[i]*=Math.exp(-delta*13);
          motion.pull[i]+=motion.velocity[i]*delta;
        }
        gl.uniform2fv(uniforms.contact,motion.contact);
        gl.uniform2fv(uniforms.pull,motion.pull);
        if(revision!==motion.paint.revision) {
          const surface=motion.paint;
          gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,surface.width,surface.height,0,gl.RGBA,gl.UNSIGNED_BYTE,surface.texture);
          revision=surface.revision;
        }
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
    const secondBraid=find('.second-braid'), motif=find('.pad-motif'), weave=find('.braid-preview');
    const motion = {touch:0,lift:-1,held:false,contact:[0,0],drag:[0,0],pull:[0,0],velocity:[0,0]};
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

    const hoofGlitter=save.hoofGlitter ?? Array(4).fill(false);
    image.src = window.glimmiePonyTexture ?? art.pony;
    motion.paint = new window.PonyPaintSurface(image,mane,feet,colors,save);
    function snapshot() {
      return JSON.stringify({
        packed, brushed, soles:sole, maneStep, maneProgress, braidStyle, crossed, maneColors, hoofColors,
        hoofGlitter, padColor, hasSaddle, girth, bow, padMarks, scratched,
        paintLayer: motion.paint.encode() ?? save.paintLayer
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

    let refreshFrame=0;
    function dab(from,to,hair,only=-1) {
      const [name,hex]=colors[tone];
      const touched=motion.paint.stroke(from,to,hair,hex?tone+1:0,glitter,only);
      if(touched<0) return false;
      (hair?maneColors:hoofColors)[touched]=hex;
      if(!hair) hoofGlitter[touched]=glitter && !!hex;
      if(motion.refresh && !refreshFrame) {
        refreshFrame=requestAnimationFrame(()=>{ refreshFrame=0; motion.refresh(); });
      }
      text(hex?name+' • Keep painting to build the color.':'The color rinses away as you brush.');
      return true;
    }

    // A dab remains available through VoiceOver and the larger hoof controls.
    function paintAt(i,hair) {
      const point=hair?mane[i]:[feet[i][0],feet[i][1]+.018];
      if(dab(point,point,hair,i)) {
        feedback(point);
        render();
      }
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

    function showStrands(anchor,end) {
      weave.hidden=false;
      const width=weave.width=Math.round(actor.clientWidth);
      const height=weave.height=Math.round(actor.clientHeight);
      const context=weave.getContext('2d');
      const [x,y]=[anchor[0]*width,anchor[1]*height];
      for(let i=2;i>=0;i--) {
        const active=i===0, dx=(i-1)*width*.024;
        const [ex,ey]=active?[end[0]*width,end[1]*height]:[x+dx*2,y+height*.16];
        const pigment=active?(maneColors[crossed%3]||'#ad633b'):'#985029';
        context.lineCap='round';
        const curve=(displacement=0)=>{
          context.beginPath();
          context.moveTo(x+dx+displacement,y-height*.095);
          context.bezierCurveTo(x+dx+displacement,y,ex-dx+displacement,ey-height*.036,ex+displacement*.60,ey);
        };
        const size=Math.max(4,width*.021);
        const finish=context.createLinearGradient(x,y-height*.075,ex,ey);
        finish.addColorStop(0,'#85502d38');
        finish.addColorStop(.20,pigment);
        finish.addColorStop(.82,pigment);
        finish.addColorStop(1,'#a85c34a8');
        context.strokeStyle=finish;
        context.lineWidth=size;
        curve();
        context.stroke();
        for(let fiber=-4;fiber<=4;fiber++) {
          curve(fiber*size*.10);
          context.strokeStyle=fiber%2===0?'#ffe0aa77':'#66341d66';
          context.lineWidth=Math.max(.36,size*.062);
          context.stroke();
        }
      }
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
        const stamp=mark(targets,point,'stable-dot stroke-guide dust'+(packed[i]?' packed':''),
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
          const target=mark(targets,point,'stable-dot hidden-dab','Color '+labels[i],()=>paintAt(i,true));
          target.style.setProperty('--mark-color',maneColors[i]||'#f6ecd988');
        });
        text(colors[tone][1]?'Paint anywhere along the mane and tail.':'Brush over the paint to rinse it away.');
      } else if(maneMode==='Comb' && maneStep<mane.length) {
        status.textContent='Comb the mane';
        mark(targets,mane[maneStep],'stable-dot stroke-guide active-knot','Comb this tangle',()=>comb(.35));
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
          mark(targets,strandSites[crossed],'stable-dot stroke-guide target-arrow','Cross '+side+' strand',cross,side==='left'?'→':'←');
          text('Grab the strand and pull it across the center.');
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
          hooves.append(swatch(name,hoofColors[i]||'#a47d62',()=>paintAt(i,false),false,'hoof-tile',hoofGlitter[i]?'✦':(i+1)));
          const target=mark(targets,point,'stable-dot hidden-dab','Paint on pony hoof '+(i+1),()=>paintAt(i,false));
          target.style.setProperty('--mark-color',hoofColors[i]||'#f6ecd988');
        });
        text(colors[tone][1]?'Paint right on the hooves. You can mix colors on the same hoof.':'Brush over the paint to rinse it away.');
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
          i===2?'Brush loose straw':'Pick pebble '+(i+1),event=>{
            if(event.detail===0) clearDebris(i,i===2 ? .35 : 1);
          });
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
      if(bridge) {
        tools.append(tool('Meadow & stickers',()=>{
          persist();
          bridge.postMessage({kind:'classicStable'});
        }));
      }
    }

    function render() {
      targets.replaceChildren(); chips.replaceChildren(); tools.replaceChildren(); stations.replaceChildren(); swatches.replaceChildren();
      swatches.hidden=true;
      hoof.hidden=lifted<0;
      game.classList.toggle('is-hoof',lifted>=0);
      game.classList.toggle('is-mane',station==='Mane');
      pad.hidden=!padColor; saddle.hidden=!hasSaddle; ribbon.hidden=!bow;
      braid.hidden=crossed===0;
      secondBraid.hidden=crossed<3;
      braid.style.clipPath=crossed===1?'inset(0 0 50% 0)':'';
      secondBraid.style.clipPath=crossed===3?'inset(0 0 50% 0)':'';
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
    const painting=()=>station==='Mane'&&maneMode==='Color'||station==='Hooves'&&hoofMode==='Paint';
    function moveTool(point, name, color) {
      brush.hidden=false;
      const image=art[name];
      if(brush.getAttribute('src')!==image) brush.src=image;
      brush.style.left=point[0]*100+'%';
      brush.style.top=point[1]*100+'%';
      brush.style.setProperty('--tool-glow',color||'transparent');
    }
    function tug(point, delta) {
      motion.contact=point;
      motion.drag=delta.map(value=>Math.max(-.083,Math.min(.083,value)));
      motion.held=true;
    }
    actor.addEventListener('pointerdown',event=>{
      if(!(station==='Coat'||station==='Mane'||painting())) return;
      if(gesture || (event.pointerType==='mouse'&&event.button!==0)) return;
      const point=at(event,actor);
      gesture={id:event.pointerId,point,painted:false,strand:null};
      if(painting()) {
        gesture.painted=dab(point,point,station==='Mane');
        if(gesture.painted) moveTool(point,'brush',colors[tone][1]);
      } else if(station==='Mane'&&maneMode==='Braid'&&braidMode&&close(point,strandSites[crossed],.10,.115)) {
        gesture.strand=strandSites[crossed];
        showStrands(gesture.strand,point);
      }
    });
    actor.addEventListener('pointermove',event=>{
      if(!gesture||event.pointerId!==gesture.id) return;
      const p=at(event,actor), q=gesture.point;
      const dx=p[0]-q[0], dy=p[1]-q[1];
      if(Math.hypot(dx,dy)<.004) return;
      if(event.isTrusted&&!actor.hasPointerCapture(event.pointerId)) actor.setPointerCapture(event.pointerId);
      gesture.point=p;
      const middle=[(p[0]+q[0])/2,(p[1]+q[1])/2];
      if(painting()) {
        if(dab(q,p,station==='Mane')) {
          gesture.painted=true;
          if(station==='Mane') tug(p,[dx*3.2,dy*3.2]);
        }
        moveTool(p,'brush',colors[tone][1]);
        return;
      }
      if(station==='Coat') {
        moveTool(p,coatTool==='Curry comb'?'curry':'brush');
        coat.forEach((center,i)=>{
          if(!close(middle,center,.093,.092)) return;
          if(coatTool==='Soft brush'&&dx>.002&&Math.abs(dy)<dx*1.7) {
            affectCoat(i,Math.min(.31,dx*7));
          } else if(coatTool==='Curry comb') {
            const a=Math.atan2(q[1]-center[1],q[0]-center[0]);
            const b=Math.atan2(p[1]-center[1],p[0]-center[0]);
            const arc=Math.atan2(Math.sin(b-a),Math.cos(b-a));
            if(Math.abs(arc)<1.15) affectCoat(i,Math.min(.20,Math.abs(arc)*.166));
          }
        });
      } else if(maneMode==='Braid'&&gesture.strand) {
        showStrands(gesture.strand,p);
        tug(gesture.strand,[p[0]-gesture.strand[0],p[1]-gesture.strand[1]]);
      } else if(maneMode==='Comb') {
        moveTool(p,'comb');
        if(close(middle,mane[Math.min(maneStep,mane.length-1)],.105,.16)) {
          tug(p,[dx*4.2,dy*4.2]);
          if(maneStep<mane.length&&dy>.002&&Math.abs(dx)<dy*1.55) comb(Math.min(.38,dy*8.2));
        }
      }
    });
    for(const eventName of ['pointerup','pointercancel','lostpointercapture']) {
      actor.addEventListener(eventName,event=>{
        if(gesture?.id!==event.pointerId) return;
        const finished=gesture;
        gesture=null;
        brush.hidden=true;
        weave.hidden=true;
        motion.held=false;
        if(finished.strand&&braidMode&&eventName==='pointerup') {
          const [x,y]=at(event,actor), direction=crossed%2===0?1:-1;
          if((x-.345)*direction>.006&&Math.abs(y-finished.strand[1])<.18) cross();
        }
        if(finished.painted) {
          feedback(finished.point);
          render();
        } else persist();
      });
      chips.addEventListener(eventName,event=>{
        if(hoofGesture?.id!==event.pointerId) return;
        const drag=hoofGesture;
        hoofGesture=null;
        if(eventName==='pointerup'&&drag.flick) clearDebris(drag.i,1);
        else {
          drag.chip.style.removeProperty('--chip-x');
          drag.chip.style.removeProperty('--chip-y');
        }
        persist();
      });
    }

    chips.addEventListener('pointerdown',event=>{
      const chip=event.target.closest('[data-chip]');
      if(chip) hoofGesture={id:event.pointerId,i:Number(chip.dataset.chip),chip,point:at(event,chips),flick:false};
    });
    chips.addEventListener('pointermove',event=>{
      if(!hoofGesture||event.pointerId!==hoofGesture.id) return;
      const p=at(event,chips), q=hoofGesture.point, i=hoofGesture.i;
      const outward=(p[0]-q[0])*(q[0]-.50)+(p[1]-q[1])*(q[1]-.46);
      if(i!==2 && hoofTool==='Hoof pick') {
        if(event.isTrusted&&!chips.hasPointerCapture(event.pointerId)) chips.setPointerCapture(event.pointerId);
        hoofGesture.chip.style.setProperty('--chip-x',(p[0]-q[0])*chips.clientWidth+'px');
        hoofGesture.chip.style.setProperty('--chip-y',(p[1]-q[1])*chips.clientHeight+'px');
        hoofGesture.flick=outward>.013;
      } else if(i===2 && Math.abs(p[0]-q[0])>.03 && Math.abs(p[1]-q[1])<.13) {
        hoofGesture.point=p;
        if(event.isTrusted&&!chips.hasPointerCapture(event.pointerId)) chips.setPointerCapture(event.pointerId);
        clearDebris(i,Math.min(.36,Math.abs(p[0]-q[0])*5));
      } else if(i!==2 && outward>.013) {
        text('Use the hoof pick for pebbles.');
      }
    });
    document.addEventListener('visibilitychange',()=>{ if(document.hidden) persist(); });
    render();
  }
  init(root);
})();
