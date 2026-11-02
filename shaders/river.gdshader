shader_type canvas_item;
uniform float flow_time = 0.0;
uniform vec2 focus = vec2(0.53,0.52);
uniform vec2 view_size = vec2(1280.0,720.0);
uniform float boat_angle = 1.5708;

void fragment() {
 vec2 uv=UV;
 // Quiet painted water: broad color masses, no fine grain or night vignette.
 vec3 col=mix(vec3(0.64,0.78,0.80),vec3(0.43,0.65,0.72),smoothstep(0.0,1.0,uv.y));
 float lilac=exp(-dot((uv-vec2(0.12,0.16))*vec2(1.8,2.2),(uv-vec2(0.12,0.16))*vec2(1.8,2.2)));
 col=mix(col,vec3(0.75,0.74,0.85),lilac*0.28);
 float wash=sin(uv.x*5.0+sin(uv.y*4.0)+flow_time*0.04)*sin(uv.y*5.5-flow_time*0.025);
 col+=vec3(0.025,0.028,0.035)*wash;
 float ribbon=pow(0.5+0.5*sin(uv.y*35.0+sin(uv.x*5.0+flow_time*0.07)*1.4+flow_time*0.15),12.0);
 col=mix(col,vec3(0.82,0.90,0.88),ribbon*0.045);
 vec2 delta=(uv-focus)*view_size;
 // Soft contact shadow follows the boat's heading, set below its waterline.
 vec2 dp=delta-vec2(4.0,11.0);
 float c=cos(boat_angle),s=sin(boat_angle);
 vec2 local=vec2(c*dp.x+s*dp.y,-s*dp.x+c*dp.y);
 float shadow=exp(-dot(local/vec2(173.0,66.0),local/vec2(173.0,66.0))*1.7);
 col=mix(col,vec3(0.24,0.43,0.53),shadow*0.30);
 // Broad, broken lantern reflections sit directly below the two warm lights.
 float warm=0.0;
 for (int i=0;i<2;i++) {
  float x=i==0?-75.0:75.0;
  vec2 light_pos=vec2(c*x,s*x)+vec2(0.0,21.0);
  vec2 q=(delta-light_pos)/vec2(29.0,43.0);
  warm+=exp(-dot(q,q)*1.5);
 }
 float reflection=0.60+0.40*pow(0.5+0.5*sin(delta.y*0.25+flow_time*1.2+sin(delta.x*0.06)),4.0);
 col=mix(col,vec3(1.0,0.84,0.55),min(warm*reflection*0.23,0.32));
 COLOR=vec4(col,1.0);
}
