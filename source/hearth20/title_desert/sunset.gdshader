shader_type sky;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void sky(){
    float altitude=max(0.0,EYEDIR.y);
    vec3 sun_direction=normalize(vec3(-.35,.16,-1.0));
    float sun_distance=length(EYEDIR-sun_direction);
    vec3 horizon=vec3(.92,.38,.10);
    vec3 zenith=vec3(.18,.13,.13);
    vec3 sky_color=mix(horizon,zenith,pow(altitude,.5));
    sky_color+=vec3(.38,.22,.075)*exp(-sun_distance*3.0);
    sky_color=mix(sky_color,vec3(1.0,.79,.39),1.0-smoothstep(.046,.049,sun_distance));
    vec2 cloud=EYEDIR.xz/max(.1,EYEDIR.y+.2)*vec2(.85,5.0);
    float bands=noise(cloud*2.0)*.65+noise(cloud*6.0)*.35;
    float wisps=smoothstep(.57,.85,bands)*smoothstep(.0,.2,altitude)*(1.0-smoothstep(.45,.8,altitude));
    COLOR=mix(sky_color,vec3(.64,.35,.21),wisps*.5);
}
