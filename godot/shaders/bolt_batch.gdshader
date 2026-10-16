shader_type canvas_item;
render_mode unshaded;
uniform int shape = 0;
varying vec4 instance_color;
void vertex() { instance_color = COLOR; }
float arrow_mask(vec2 p) {
	float shaft = step(abs(p.y),0.14)*step(abs(p.x),0.78);
	float head = step(abs(p.y)+abs(p.x-0.42)*0.85,0.48)*step(0.08,p.x);
	float feather = step(abs(abs(p.y)-(-p.x-0.22)*0.8),0.12)*step(-0.85,p.x)*step(p.x,-0.28);
	return max(max(shaft,head),feather);
}
void fragment() {
	vec2 p = (UV-vec2(0.5))*2.0;
	float alpha = 0.0;
	vec3 tint = instance_color.rgb;
	if (shape==0) {
		float radius = max(abs(p.x),abs(p.y));
		alpha = 1.0-smoothstep(0.72,0.80,radius);
		float carved = step(0.40,radius)*step(radius,0.52);
		tint = mix(tint,vec3(0.91,0.87,0.77),carved);
	} else if (shape==1) {
		float edge = abs(p.y)+abs(p.x)*0.25;
		alpha = 1.0-smoothstep(0.50,0.58,edge);
	} else if (shape==2) {
		float edge = max(abs(p.x)*0.65,abs(p.y));
		alpha = 1.0-smoothstep(0.70,0.78,edge);
		float stamp = step(abs(p.x),0.16)*step(abs(p.y),0.54);
		tint = mix(tint,vec3(0.91,0.87,0.77),stamp);
	} else if (shape==3) {
		alpha = step(abs(p.y),0.16)*step(0.20,UV.x)*step(UV.x,0.78)*0.48;
	} else if (shape==4) {
		alpha = (1.0-smoothstep(0.90,1.0,length(p)))*0.40;
	} else if (shape==6) {
		float radius = length(p);
		alpha = 1.0-smoothstep(0.72,0.80,radius);
		float carved = step(0.36,radius)*step(radius,0.48);
		tint = mix(tint,vec3(0.91,0.87,0.77),carved);
	} else if (shape==7) {
		alpha = (1.0-smoothstep(0.58,0.65,abs(p.x)))*step(abs(p.y),0.78);
		float frame = step(0.38,abs(p.x))+step(0.60,abs(p.y));
		float flame = step(abs(p.x-p.y*0.12),0.13)*step(abs(p.y),0.34);
		tint = mix(tint,vec3(0.91,0.87,0.77),clamp(frame+flame,0.0,1.0));
	} else if (shape==8) {
		float edge = max(abs(p.x)*0.87+abs(p.y)*0.5,abs(p.y));
		alpha = 1.0-smoothstep(0.74,0.82,edge);
		float incision = step(abs(p.x),0.07)+step(abs(p.y),0.07);
		tint = mix(tint,vec3(0.91,0.87,0.77),clamp(incision,0.0,1.0));
	} else if (shape==9) {
		float radius = length(p);
		alpha = step(0.28,radius)*(1.0-smoothstep(0.45,0.53,radius));
		alpha = max(alpha,step(0.64,radius)*(1.0-smoothstep(0.75,0.83,radius)));
		alpha = max(alpha,step(abs(p.x)+abs(p.y),0.18));
	} else if (shape==10) {
		alpha = 1.0-smoothstep(0.72,0.80,length(p));
		float cut = step(abs(p.x),0.06)*step(abs(p.y),0.39);
		cut = max(cut,step(abs(p.y),0.06)*step(abs(p.x),0.39));
		tint = mix(tint,vec3(0.91,0.87,0.77),cut);
	} else if (shape==11) {
		float shaft = step(abs(p.y),0.08)*step(abs(p.x),0.70);
		float head = step(abs(p.y)+abs(p.x-0.45)*0.75,0.42)*step(0.13,p.x);
		alpha = max(shaft,head);
	} else if (shape==12) {
		alpha = 1.0-smoothstep(0.75,0.84,abs(p.x)+abs(p.y));
		float zig = step(abs(p.x+p.y*0.52-sign(p.y)*0.12),0.11)*step(abs(p.y),0.60);
		tint = mix(tint,vec3(0.91,0.87,0.77),zig);
	} else if (shape==13) {
		alpha = arrow_mask(p);
		tint = mix(vec3(0.09,0.21,0.27),vec3(0.98,0.94,0.83),arrow_mask(p*1.15));
		tint = mix(tint,vec3(0.76,0.17,0.12),arrow_mask(p*1.6));
	} else if (shape==14) {
		float radius = length(p);
		alpha = step(radius,0.92);
		tint = mix(vec3(0.09,0.21,0.27),vec3(0.98,0.94,0.83),step(radius,0.79));
		tint = mix(tint,vec3(0.76,0.17,0.12),step(radius,0.62));
		tint = mix(tint,vec3(0.98,0.94,0.83),step(abs(p.x)+abs(p.y),0.28));
	} else if (shape==15) {
		float feather = step(abs(abs(p.y)-(-p.x+0.1)*0.55),0.09)*step(abs(p.x),0.7);
		alpha = feather;
		tint = vec3(0.76,0.17,0.12);
	} else if (shape==16) {
		float edge=abs(p.x)/(p.x>=0.0?1.0:0.35)+abs(p.y)/(p.y>=0.0?1.0:0.6);
		alpha=1.0-smoothstep(0.96,1.0,edge);
	} else if (shape==17) {
		alpha=1.0;
		float body=step(abs(p.x),0.79)*step(abs(p.y),0.89);
		tint=mix(vec3(0.09,0.21,0.27),vec3(0.98,0.94,0.83),body);
		float stroke=step(abs(p.x),0.08)*step(abs(p.y),0.66);
		float bars=step(abs(p.x),0.5)*step(min(abs(p.y),abs(abs(p.y)-0.37)),0.055);
		tint=mix(tint,vec3(0.68,0.21,0.15),max(stroke,bars));
	} else if (shape==18) {
		float radius=length(p);
		alpha=(1.0-smoothstep(0.92,0.98,radius))*smoothstep(0.68,0.72,radius)*step(atan(p.y,p.x),1.73);
		tint=mix(vec3(0.09,0.21,0.27),vec3(0.98,0.94,0.83),step(radius,0.80));
	} else if (shape==19) {
		float y=p.y-sin(p.x*5.2+instance_color.r*6.283)*0.12;
		float distance=min(abs(y),abs(abs(y)-0.62));
		alpha=(1.0-smoothstep(0.025,0.07,distance))*step(abs(p.x),0.95);
		tint=vec3(0.09,0.21,0.27);
	} else if (shape==20) {
		alpha=1.0-smoothstep(0.79,0.85,length(p));
		tint=mix(tint,vec3(0.357,0.38,0.278),step(max(abs(p.x),abs(p.y)),0.25));
	} else if (shape==21) {
		alpha=1.0-smoothstep(0.95,1.0,abs(p.x)*1.5+abs(p.y));
	} else {
		alpha = 1.0;
	}
	COLOR = vec4(tint,alpha*instance_color.a);
}
