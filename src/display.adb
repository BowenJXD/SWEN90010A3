with Ada.Text_IO;
with Ada.Float_Text_IO;
with Vector;
with Spatial;

package body Display with SPARK_Mode => Off is

   type World_Point is record
      X  : Float;
      Y  : Float;
      R  : Float;
      VX : Float;
      VY : Float;
   end record;

   type Point_Array is
     array (Positive range 1 .. Univ.Max_Items) of World_Point;

   type Frame is record
      Points : Point_Array;
      Count  : Natural := 0;
   end record;

   type Frame_Array is array (Positive range 1 .. Max_Frames) of Frame;

   Frames      : Frame_Array;
   Frame_Count : Natural := 0;

   function To_Float (V : Big_Real) return Float is
      S : constant String := To_String (V);
   begin
      return Float'Value (S);
   end To_Float;

   procedure Capture (U : Univ.Universe) is
      Pos : Spatial.Position;
      Vel : Vector.Vector;
      F   : Frame;
   begin
      if Frame_Count >= Max_Frames then
         return;
      end if;

      F.Count := 0;

      for I in 1 .. Univ.Item_Count (U) loop
         if F.Count < Univ.Max_Items then
            Pos := Univ.Get_Position (U, I);
            Vel := Spatial.Vel_To_Vector (Univ.Get_Velocity (U, I));
            F.Count := F.Count + 1;
            F.Points (F.Count) :=
              (X => To_Float (Spatial.Pos_X (Pos)),
               Y => To_Float (Spatial.Pos_Y (Pos)),
               VX => To_Float (Vel.X), VY => To_Float (Vel.Y),
               R => To_Float (Univ.Get_Radius (U, I)));
         end if;
      end loop;

      Frame_Count := Frame_Count + 1;
      Frames (Frame_Count) := F;
   end Capture;

   procedure Put_Float (File : Ada.Text_IO.File_Type; V : Float) is
   begin
      Ada.Float_Text_IO.Put (File, V, Fore => 1, Aft => 4, Exp => 0);
   end Put_Float;

   procedure Save
     (Filename : String;
      Arena_X_Min, Arena_X_Max,
      Arena_Y_Min, Arena_Y_Max : Big_Real)
   is
      use Ada.Text_IO;
      File : File_Type;
      AXMin : constant Float := To_Float (Arena_X_Min);
      AXMax : constant Float := To_Float (Arena_X_Max);
      AYMin : constant Float := To_Float (Arena_Y_Min);
      AYMax : constant Float := To_Float (Arena_Y_Max);
   begin
      Create (File, Out_File, Filename);

      Put_Line (File, "<!DOCTYPE html>");
      Put_Line (File, "<html><head>");
      Put_Line (File, "<meta charset=""utf-8"">");
      Put_Line (File, "<title>Universe Simulation</title>");
      Put_Line (File, "<style>");
      Put_Line (File,
        "body{margin:0;background:#111;display:flex;" &
        "flex-direction:column;align-items:center;" &
        "font-family:monospace;color:#eee;}");
      Put_Line (File,
        "canvas{border:1px solid #444;cursor:grab;" &
        "margin-top:10px;}");
      Put_Line (File,
        "canvas:active{cursor:grabbing;}");
      Put_Line (File,
        "#controls{margin:10px;user-select:none;}");
      Put_Line (File,
        "button{margin:0 3px;padding:5px 12px;" &
        "background:#333;color:#eee;border:1px solid #555;" &
        "cursor:pointer;font-family:monospace;}");
      Put_Line (File,
        "button:hover{background:#555;}");
      Put_Line (File,
        "#info{margin-left:10px;}");
      Put_Line (File, "</style>");
      Put_Line (File, "</head><body>");

      Put_Line (File,
        "<canvas id=""c"" width=""1200"" height=""600""></canvas>");

      Put_Line (File, "<div id=""controls"">");
      Put_Line (File,
        "<button onclick=""stepBack()"">&lt; Prev</button>");
      Put_Line (File,
        "<button onclick=""togglePlay()"" id=""playBtn"">" &
        "Play</button>");
      Put_Line (File,
        "<button onclick=""stepFwd()"">Next &gt;</button>");
      Put_Line (File,
        "<button onclick=""resetView()"">Reset View</button>");
      Put_Line (File,
        "<button onclick=""fitAll()"">Fit All</button>");
      Put_Line (File,
        "<span id=""info"">Frame: 1</span>");
      Put_Line (File, "</div>");
      Put_Line (File,
        "<div style=""margin:5px;width:1200px;"">");
      Put_Line (File,
        "<input type=""range"" id=""slider"" min=""0"" " &
        "value=""0"" style=""width:100%;""/>");
      Put_Line (File, "</div>");

      --  Embed frame data as JSON (world coordinates)
      Put_Line (File, "<script>");
      Put (File, "const frames=[");
      for FI in 1 .. Frame_Count loop
         if FI > 1 then
            Put (File, ",");
         end if;
         Put (File, "[");
         for PI in 1 .. Frames (FI).Count loop
            if PI > 1 then
               Put (File, ",");
            end if;
            Put (File, "[");
            Put_Float (File, Frames (FI).Points (PI).X);
            Put (File, ",");
            Put_Float (File, Frames (FI).Points (PI).Y);
            Put (File, ",");
            Put_Float (File, Frames (FI).Points (PI).R);
            Put (File, ",");
            Put_Float (File, Frames (FI).Points (PI).VX);
            Put (File, ",");
            Put_Float (File, Frames (FI).Points (PI).VY);
            Put (File, "]");
         end loop;
         Put (File, "]");
      end loop;
      Put_Line (File, "];");

      --  JS animation engine with pan/zoom
      Put_Line (File, "const canvas=document.getElementById('c');");
      Put_Line (File, "const ctx=canvas.getContext('2d');");
      Put_Line (File, "const info=document.getElementById('info');");
      Put_Line (File,
        "const playBtn=document.getElementById('playBtn');");
      Put_Line (File, "const CW=canvas.width, CH=canvas.height;");
      Put_Line (File,
        "const slider=document.getElementById('slider');");
      Put_Line (File,
        "slider.max=frames.length-1;");
      Put_Line (File,
        "slider.addEventListener('input',e=>{" &
        "stopPlay();frame=+e.target.value;draw();});");

      --  Viewport state (world coordinates)
      Put_Line (File, "let vp={ox:0,oy:0,w:100,h:50};");
      Put_Line (File,
        "let frame=0,playing=false,timer=null,interval=20;");

      --  Compute bounding box of all frames
      Put_Line (File, "function bbox(){");
      Put_Line (File,
        "  let x0=Infinity,y0=Infinity,x1=-Infinity,y1=-Infinity;");
      Put_Line (File, "  for(const fr of frames)for(const p of fr){");
      Put_Line (File,
        "    const r=p[2];");
      Put_Line (File,
        "    if(p[0]-r<x0)x0=p[0]-r;if(p[0]+r>x1)x1=p[0]+r;");
      Put_Line (File,
        "    if(p[1]-r<y0)y0=p[1]-r;if(p[1]+r>y1)y1=p[1]+r;");
      Put_Line (File, "  }");
      Put_Line (File,
        "  const margin=0.1;");
      Put_Line (File,
        "  const dx=(x1-x0)*margin||10,dy=(y1-y0)*margin||10;");
      Put_Line (File,
        "  return{x0:x0-dx,y0:y0-dy,x1:x1+dx,y1:y1+dy};");
      Put_Line (File, "}");

      --  Fit viewport to all data
      Put_Line (File, "function fitAll(){");
      Put_Line (File, "  const b=bbox();");
      Put_Line (File, "  let w=b.x1-b.x0,h=b.y1-b.y0;");
      Put_Line (File,
        "  const aspect=CW/CH;");
      Put_Line (File,
        "  if(w/h<aspect)w=h*aspect;else h=w/aspect;");
      Put_Line (File,
        "  const cx=(b.x0+b.x1)/2,cy=(b.y0+b.y1)/2;");
      Put_Line (File,
        "  vp.ox=cx-w/2;vp.oy=cy+h/2;vp.w=w;vp.h=h;");
      Put_Line (File, "  draw();");
      Put_Line (File, "}");

      Put_Line (File, "function resetView(){fitAll();}");

      --  World to screen mapping
      Put_Line (File,
        "function w2sx(x){return(x-vp.ox)/vp.w*CW;}");
      Put_Line (File,
        "function w2sy(y){return(vp.oy-y)/vp.h*CH;}");

      --  Draw current frame
      Put_Line (File, "function draw(){");
      Put_Line (File, "  ctx.fillStyle='#000';");
      Put_Line (File, "  ctx.fillRect(0,0,CW,CH);");
      --  Grid
      Put_Line (File, "  ctx.strokeStyle='#222';ctx.lineWidth=1;");
      Put_Line (File, "  ctx.beginPath();");
      Put_Line (File,
        "  const gx=Math.pow(10," &
        "Math.floor(Math.log10(vp.w))-1)*2;");
      Put_Line (File,
        "  const gy=Math.pow(10," &
        "Math.floor(Math.log10(vp.h))-1)*2;");
      Put_Line (File,
        "  for(let x=Math.floor(vp.ox/gx)*gx;" &
        "x<vp.ox+vp.w;x+=gx){");
      Put_Line (File,
        "    const sx=w2sx(x);ctx.moveTo(sx,0);ctx.lineTo(sx,CH);}");
      Put_Line (File,
        "  for(let y=Math.floor((vp.oy-vp.h)/gy)*gy;" &
        "y<vp.oy;y+=gy){");
      Put_Line (File,
        "    const sy=w2sy(y);ctx.moveTo(0,sy);ctx.lineTo(CW,sy);}");
      Put_Line (File, "  ctx.stroke();");
      --  Axes
      Put_Line (File, "  const ax=w2sx(0),ay=w2sy(0);");
      Put_Line (File,
        "  ctx.strokeStyle='#444';ctx.beginPath();");
      Put_Line (File,
        "  ctx.moveTo(ax,0);ctx.lineTo(ax,CH);");
      Put_Line (File,
        "  ctx.moveTo(0,ay);ctx.lineTo(CW,ay);");
      Put_Line (File, "  ctx.stroke();");
      --  Arena bounds
      Put_Line (File,
        "  ctx.strokeStyle='#c44';ctx.lineWidth=2;");
      Put_Line (File, "  ctx.beginPath();");
      Put (File, "  const ax0=w2sx(");
      Put_Float (File, AXMin);
      Put (File, "),ay0=w2sy(");
      Put_Float (File, AYMax);
      Put (File, "),ax1=w2sx(");
      Put_Float (File, AXMax);
      Put (File, "),ay1=w2sy(");
      Put_Float (File, AYMin);
      Put_Line (File, ");");
      Put_Line (File,
        "  ctx.rect(ax0,ay0,ax1-ax0,ay1-ay0);");
      Put_Line (File, "  ctx.stroke();");
      --  Items
      Put_Line (File, "  const pts=frames[frame];");
      Put_Line (File, "  for(let i=0;i<pts.length;i++){");
      Put_Line (File,
        "    const sx=w2sx(pts[i][0]),sy=w2sy(pts[i][1]);");
      Put_Line (File,
        "    const r=Math.max(2,pts[i][2]/vp.w*CW);");
      Put_Line (File, "    ctx.fillStyle='hsl('+(i*137)%360+',80%,60%)';");
      Put_Line (File,
        "    ctx.beginPath();ctx.arc(sx,sy,r,0,Math.PI*2);");
      Put_Line (File, "    ctx.fill();");
      --  Velocity arrow
      Put_Line (File,
        "    const vx=pts[i][3],vy=pts[i][4];");
      Put_Line (File,
        "    const vlen=Math.sqrt(vx*vx+vy*vy);");
      Put_Line (File, "    if(vlen>0){");
      Put_Line (File,
        "      const scale=r*3/vlen;");
      Put_Line (File,
        "      const ex=sx+vx*scale,ey=sy-vy*scale;");
      Put_Line (File,
        "      ctx.strokeStyle='hsl('+(i*137)%360+',80%,80%)';");
      Put_Line (File,
        "      ctx.lineWidth=2;ctx.beginPath();");
      Put_Line (File,
        "      ctx.moveTo(sx,sy);ctx.lineTo(ex,ey);ctx.stroke();");
      --  Arrowhead
      Put_Line (File,
        "      const al=6,nx=vx/vlen,ny=-vy/vlen;");
      Put_Line (File,
        "      ctx.fillStyle='hsl('+(i*137)%360+',80%,80%)';");
      Put_Line (File,
        "      ctx.beginPath();ctx.moveTo(ex,ey);");
      Put_Line (File,
        "      ctx.lineTo(ex-al*(nx-ny*0.4)," &
        "ey-al*(ny+nx*0.4));");
      Put_Line (File,
        "      ctx.lineTo(ex-al*(nx+ny*0.4)," &
        "ey-al*(ny-nx*0.4));");
      Put_Line (File,
        "      ctx.closePath();ctx.fill();");
      Put_Line (File, "    }");
      --  Label
      Put_Line (File,
        "    ctx.fillStyle='#fff';ctx.font='10px monospace';");
      Put_Line (File,
        "    ctx.fillText((i+1),sx+r+2,sy-r);");
      Put_Line (File, "  }");
      Put_Line (File,
        "  info.textContent='Frame: '+(frame+1)+'/'+" &
        "frames.length+" &
        "' | View: ('+vp.ox.toFixed(1)+','" &
        "+(vp.oy-vp.h).toFixed(1)+') w='+vp.w.toFixed(1);");
      Put_Line (File, "  slider.value=frame;");
      Put_Line (File, "}");

      --  Playback controls
      Put_Line (File, "function advance(){");
      Put_Line (File,
        "  if(frame<frames.length-1){frame++;draw();}");
      Put_Line (File, "  else stopPlay();}");
      Put_Line (File, "function stepFwd(){");
      Put_Line (File,
        "  stopPlay();" &
        "if(frame<frames.length-1){frame++;draw();}}");
      Put_Line (File, "function stepBack(){");
      Put_Line (File,
        "  stopPlay();" &
        "if(frame>0){frame--;draw();}}");
      Put_Line (File,
        "function stopPlay(){playing=false;" &
        "if(timer){clearInterval(timer);timer=null;}" &
        "playBtn.textContent='Play';}");
      Put_Line (File, "function togglePlay(){");
      Put_Line (File, "  if(playing){stopPlay();}");
      Put_Line (File,
        "  else{playing=true;playBtn.textContent='Pause';" &
        "timer=setInterval(advance,interval);}}");

      --  Mouse pan
      Put_Line (File, "let dragging=false,lastX=0,lastY=0;");
      Put_Line (File,
        "canvas.addEventListener('mousedown',e=>{");
      Put_Line (File,
        "  dragging=true;lastX=e.clientX;lastY=e.clientY;});");
      Put_Line (File,
        "canvas.addEventListener('mousemove',e=>{");
      Put_Line (File, "  if(!dragging)return;");
      Put_Line (File,
        "  const dx=(e.clientX-lastX)/CW*vp.w;");
      Put_Line (File,
        "  const dy=(e.clientY-lastY)/CH*vp.h;");
      Put_Line (File,
        "  vp.ox-=dx;vp.oy+=dy;");
      Put_Line (File,
        "  lastX=e.clientX;lastY=e.clientY;draw();});");
      Put_Line (File,
        "canvas.addEventListener('mouseup',()=>dragging=false);");
      Put_Line (File,
        "canvas.addEventListener('mouseleave'," &
        "()=>dragging=false);");

      --  Scroll wheel zoom (centred on mouse)
      Put_Line (File,
        "canvas.addEventListener('wheel',e=>{");
      Put_Line (File, "  e.preventDefault();");
      Put_Line (File,
        "  const rect=canvas.getBoundingClientRect();");
      Put_Line (File,
        "  const mx=(e.clientX-rect.left)/CW;");
      Put_Line (File,
        "  const my=(e.clientY-rect.top)/CH;");
      Put_Line (File,
        "  const wx=vp.ox+mx*vp.w;");
      Put_Line (File,
        "  const wy=vp.oy-my*vp.h;");
      Put_Line (File,
        "  const factor=e.deltaY>0?1.15:1/1.15;");
      Put_Line (File,
        "  vp.w*=factor;vp.h*=factor;");
      Put_Line (File,
        "  vp.ox=wx-mx*vp.w;vp.oy=wy+my*vp.h;");
      Put_Line (File,
        "  draw();},{passive:false});");

      --  Keyboard controls
      Put_Line (File,
        "document.addEventListener('keydown',e=>{");
      Put_Line (File,
        "  if(e.key===' ')togglePlay();");
      Put_Line (File,
        "  else if(e.key==='ArrowRight')stepFwd();");
      Put_Line (File,
        "  else if(e.key==='ArrowLeft')stepBack();");
      Put_Line (File,
        "  else if(e.key==='f')fitAll();");
      Put_Line (File, "});");

      --  Initial view
      Put_Line (File, "fitAll();");

      Put_Line (File, "</script>");
      Put_Line (File, "</body></html>");

      Close (File);
   end Save;

end Display;
