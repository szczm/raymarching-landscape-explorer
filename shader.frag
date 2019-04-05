#define EPSILON 0.01

// materials
#define MAT_NONE   -1.0
#define MAT_BB      1.0  // Bounding Box
#define MAT_FLOOR   2.0

#define MAT_WATER 101.0

uniform vec2 screenResolution;
uniform float time;
uniform float fov;

uniform vec3 origin;
uniform vec3 direction;
uniform vec3 rotation;

uniform float worldHeight;
uniform float worldSize;

uniform Image heightMap;
uniform Image colorMap;
uniform Image skyboxMap;

uniform vec3 sunPosition;

uniform float colorNormalVariance;

uniform float waterHeight;
uniform float waterDensity;
uniform float waterFluorescence;
uniform vec3 waterColor;

uniform float shadowRoughness;
uniform float shadowInfluence;

uniform float fogDensity;

uniform float skyExponent;

uniform Image vegetationMap;
uniform Image vegetationColorMap;
uniform Image vegetationVarianceMap;

uniform vec3 dayCycle;

// below union_, intersect_ and box_ functions use vec2 to transfer material data (.y)
vec2 union_(vec2 a, vec2 b)
{
	return mix(a, b, step(0.0, a.x - b.x));
}

vec2 intersect_(vec2 a, vec2 b)
{
	return mix(b, a, step(0.0, a.x - b.x));
}

float box_(vec3 p, vec3 b) // inigo quilez - distance functions - box, signed, exact
{
	vec3 d = abs(p) - b;
	return min(max(d.x,max(d.y, d.z)),0.0) + length(max(d,0.0)); // credits: Inigo Quilez (iquilezles.org)
}

float planeTexel(vec3 p)
{
	return p.y - Texel(heightMap, p.xz / worldSize)[0] * worldHeight;
}

vec2 scene(vec3 p)
{
	vec3 worldBB = vec3(worldSize, worldHeight * 2.0, worldSize) / 2.0 - 0.5;
	float planeSDF = planeTexel(p - vec3(worldSize / 2.0, 0.0, worldSize / 2.0));
	float boundingSDF = box_(p - vec3(0.0, worldHeight, 0.0), worldBB);

	vec2 plane = vec2(planeSDF, MAT_FLOOR);
	vec2 boundingBox = vec2(-boundingSDF, MAT_BB);

    return union_(plane, boundingBox);
}

vec3 normal(vec3 p, float epsilon)
{
	vec2 e = vec2(epsilon, 0.0);

	vec3 n = vec3(
		scene(p + e.yxy).x - scene(p - e.xyy).x,
		scene(p + e.yxy).x - scene(p - e.yxy).x,
		scene(p + e.yyx).x - scene(p - e.yyx).x
	);

	return normalize(n);
}

vec2 trace(vec3 p, vec3 dir)
{
	vec2 t = vec2(0.0, -1.0);

	for (int i = 0; i < 5000; i++)
	{
		vec2 hit = scene(p + dir * t.x);

		t.x += hit.x * 0.5; // improve quality in exchange for performance
		t.y = hit.y;

		if (hit.x < EPSILON) break;
	}

	// if (t.x > worldSize / 2.0) return vec3(-1.0, MAT_NONE, MAT_NONE);

	return t;
}

float shadow(vec3 p)
{
	float shadow = 1.0;
	vec3 dir = sunPosition;

	for (float i = 0.5; i < 10.0; i += 0.1)
	{
		vec2 hit = scene(p + dir * i);

		if (hit.y == MAT_BB) continue;
		
		shadow = min(shadow, shadowRoughness * hit.x / i);
		
		if (hit.x < EPSILON) break;
	}

	return max(shadow, 0.0);
}

float vegetation(vec3 p, vec3 n)
{
	vec2 pp = p.xz / worldSize;
	
	float samp = Texel(vegetationMap, 4.0 * pp)[0];

	// vegetation is biased to grow on the sun's "path"
	float toSun = max(0.0, dot(normalize(n.xy), vec2(sin(dayCycle[2]), cos(dayCycle[2]))));

	float bias = 1.0 - smoothstep(waterHeight + 5.0, worldHeight, p.y) * pow(toSun, shadowInfluence);
	float var = Texel(vegetationVarianceMap, pp)[0];
	return smoothstep(0.6, 0.95, samp - 0.4 * bias - 0.2 * var);
}

vec3 rayDirection(float fov, vec2 size, vec2 fragCoord)
{
	vec2 xy = fragCoord - size / 2.0;
	float z = size.y / tan(radians(fov) / 2.0);
	return normalize(vec3(xy, -z));
}

mat3 viewMatrix(vec3 eye)
{
	vec3 s = normalize(cross(direction, vec3(0.0, -1.0, 0.0)));
	vec3 u = cross(s, direction);
	return mat3(s, u, -direction);
}

vec4 effect(vec4 colo, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec3 viewDir = rayDirection(fov, screenResolution, screen_coords);

	mat3 viewToWorld = viewMatrix(origin);
    
	vec3 worldDir = viewToWorld * viewDir;

	vec2 t = trace(origin, worldDir);
	vec3 w = origin + worldDir * t.x;
	vec3 bn = normal(w, 0.15); // worldSize / textureSize
	vec3 n = normal(w, 0.05);  // like above but 3x smaller

	float sunbias = 0.5 + 0.5 * dot(worldDir, sunPosition);
	sunbias = pow(sunbias, skyExponent);

    // start by sampling the sky
	vec3 color = Texel(skyboxMap, vec2(sunbias, 0.0)).rgb;
	color *= (1.0 - shadowInfluence) + shadowInfluence * sunbias;

	if (t.y == MAT_BB) // if ray hit the bounding box, let's remind the user it's a simulation
	{
		float flicker = (0.9 + 0.1 * sin(time * 2.0 + sin(0.1 * (w.x*0.5 + w.y + w.z*0.5) + time * 0.2)));

		flicker *= smoothstep(0.9, 0.95, sin(w.z * 20.0)) +
			   smoothstep(0.9, 0.95, sin(w.y * 20.0)) +
			   smoothstep(0.9, 0.95, sin(w.x * 20.0));

		flicker = min(flicker, 1.0);

		vec3 color2 = vec3(0.0, flicker, flicker);

		color = mix(color, color2, 0.8 * smoothstep(5.0, 4.5, t.x));
	}

	if (t.y == MAT_FLOOR)
	{
		color = Texel(colorMap, vec2(w.y / worldHeight - (n.y - 0.5) * colorNormalVariance, 0.0)).rgb;
		
		//vec3 lightcolor = Texel(skyboxMap, vec2(bn.y * -0.5 + 0.5, 0.0)).rgb;
		//float lightbrightness = 0.2126 * lightcolor.r + 0.7152 * lightcolor.g + 0.0722 * lightcolor.b;
		
		//color += lightcolor * 0.25 * smoothstep(-0.5, 0.5, sin(time));

		float veg = vegetation(w, n);
		vec3 vegCol = Texel(vegetationColorMap, vec2(0.2 * veg + 0.2 * (w.y / worldHeight), 0.0)).rgb;
		
		color = pow(color, vec3(1.0/2.2));
		vegCol = pow(vegCol, vec3(1.0/2.2));
		color = mix(color, vegCol, veg);
		color = pow(color, vec3(2.2));

		color *= (1.0 - shadowInfluence) + shadowInfluence * shadow(w);

		color += waterColor * smoothstep(2.0, 0.0, w.y - waterHeight) * waterFluorescence;
	}


	float u = min(origin.y, w.y);

	if (u < waterHeight) // analitycal water/fog
	{
		float miny = u;
		float maxy = min(waterHeight, max(origin.y, w.y));

		float uu = min(origin.y - waterHeight, 0.0);

		float uf = (maxy - miny) / abs(w.y - origin.y);
		float uw = t.x * uf;

		vec3 wp = origin + (1.0 - uf) * t.x * worldDir; // surface point
		vec3 watercolor = waterColor;
		float sf = mix(shadowInfluence, 0.0, waterFluorescence);
		watercolor *= (1.0 - sf) + sf * shadow(wp);
		watercolor *= 0.7 + 0.3 * smoothstep(5.0, 0.0, scene(wp).x);

		// the "1.0 / (-uu + 1.0) part is making the screen darker the further underwater you go
		color = mix(color, watercolor, smoothstep(0.0, waterDensity, uw)) * 1.0 / (-uu + 1.0);
	}

	color = pow(color, vec3(2.2)); // gamma correction
	
	return vec4(color, 1.0);
}
