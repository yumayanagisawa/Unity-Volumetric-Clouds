// Based on this shader by iq https://www.shadertoy.com/view/XslGRr
Shader "Unlit/Clouds"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		iChannel0("Texture Noise", 2D) = "white" {}
		iMouse("Temp Guide", Vector) = (0,0,0,0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

			sampler2D iChannel0;
			float4 iMouse;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

			float noise(in float3 x)
			{
				float3 p = floor(x);
				float3 f = frac(x);
				f = f * f * (3.0 - 2.0 * f);

			#if 1
				float2 uv = (p.xy + float2(37.0, 17.0) * p.z) + f.xy;
				//uv.y = 1.0 - uv.y;
				//float2 rg = textureLod(iChannel0, (uv + 0.5) / 256.0, 0.).yx;
				float4 tempPos = float4((uv + 0.5) / 256.0, 0., 0.);
				float4 tempTex = tex2Dlod(iChannel0, tempPos);
				float2 rg = tempTex.yx;
			#else
				int3 q = int3(p);
				int2 uv = q.xy + int2(37, 17) * q.z;

				int2 rg = lerp(lerp(texelFetch(iChannel0, (uv) & 255, 0),
					texelFetch(iChannel0, (uv + int2(1, 0)) & 255, 0), f.x),
					lerp(texelFetch(iChannel0, (uv + int2(0, 1)) & 255, 0),
						texelFetch(iChannel0, (uv + int2(1, 1)) & 255, 0), f.x), f.y).yx;
			#endif    

				return -1.0 + 2.0 * lerp(rg.x, rg.y, f.z);
			}

			float map5(in float3 p)
			{
				float3 q = p - float3(0.0, 0.1, 1.0) * _Time.y;
				float f;
				f = 0.50000 * noise(q); q = q * 2.02;
				f += 0.25000 * noise(q); q = q * 2.03;
				f += 0.12500 * noise(q); q = q * 2.01;
				f += 0.06250 * noise(q); q = q * 2.02;
				f += 0.03125 * noise(q);
				return clamp(1.5 - p.y - 2.0 + 1.75 * f, 0.0, 1.0);
			}
			float map4(in float3 p)
			{
				float3 q = p - float3(0.0, 0.1, 1.0) * _Time.y;
				float f;
				f = 0.50000 * noise(q); q = q * 2.02;
				f += 0.25000 * noise(q); q = q * 2.03;
				f += 0.12500 * noise(q); q = q * 2.01;
				f += 0.06250 * noise(q);
				return clamp(1.5 - p.y - 2.0 + 1.75 * f, 0.0, 1.0);
			}
			float map3(in float3 p)
			{
				float3 q = p - float3(0.0, 0.1, 1.0) * _Time.y;
				float f;
				f = 0.50000 * noise(q); q = q * 2.02;
				f += 0.25000 * noise(q); q = q * 2.03;
				f += 0.12500 * noise(q);
				return clamp(1.5 - p.y - 2.0 + 1.75 * f, 0.0, 1.0);
			}
			float map2(in float3 p)
			{
				float3 q = p - float3(0.0, 0.1, 1.0) * _Time.y;
				float f;
				f = 0.50000 * noise(q); q = q * 2.02;
				f += 0.25000 * noise(q);;
				return clamp(1.5 - p.y - 2.0 + 1.75 * f, 0.0, 1.0);
			}

			float3 sundir = normalize(float3(-1.0, 0.0, -1.0));

			float4 integrate(in float4 sum, in float dif, in float den, in float3 bgcol, in float t)
			{
				// lighting
				float3 lin = float3(0.65, 0.7, 0.75) * 1.4 + float3(1.0, 0.6, 0.3) * dif;
				float4 col = float4(lerp(float3(1.0, 0.95, 0.8), float3(0.25, 0.3, 0.35), den), den);
				col.xyz *= lin;
				col.xyz = lerp(col.xyz, bgcol, 1.0 - exp(-0.003 * t * t));
				// front to back blending    
				col.a *= 0.4;
				col.rgb *= col.a;
				return sum + col * (1.0 - sum.a);
			}
			#define MARCH(STEPS,MAPLOD) for(int i=0; i<STEPS; i++) { float3  pos = ro + t*rd; if( pos.y<-3.0 || pos.y>2.0 || sum.a > 0.99 ) break; float den = MAPLOD( pos ); if( den>0.01 ) { float dif =  clamp((den - MAPLOD(pos+0.3*sundir))/0.6, 0.0, 1.0 ); sum = integrate( sum, dif, den, bgcol, t ); } t += max(0.05,0.02*t); }

			float4 raymarch(in float3 ro, in float3 rd, in float3 bgcol, in int2 px)
			{
				float4 sum = float4(0.0, 0.0, 0.0, 0.0);

				//float t = 0.05*texelFetch( iChannel0, px&255, 0 ).x;
				float t = 0.0f;//0.05*tex2Dlod(iChannel0, px & 255, 0).x;

				MARCH(50, map5);
				MARCH(50, map4);
				MARCH(50, map3);
				MARCH(50, map2);

				return clamp(sum, 0.0, 1.0);
			}

			float3x3 setCamera(in float3 ro, in float3 ta, float cr)
			{
				float3 cw = normalize(ta - ro);
				float3 cp = float3(sin(cr), cos(cr), 0.0);
				float3 cu = normalize(cross(cw, cp));
				float3 cv = normalize(cross(cu, cw));
				return float3x3(cu, cv, cw);
			}
			float4 render(in float3 ro, in float3 rd, in int2 px)
			{
				// background sky     
				float sun = clamp(dot(sundir, rd), 0.0, 1.0);
				float3 col = float3(0.6, 0.71, 0.75) - rd.y * 0.2 * float3(1.0, 0.5, 1.0) + 0.15 * 0.5;
				col += 0.2 * float3(1.0, .6, 0.1) * pow(sun, 8.0);

				// clouds    
				float4 res = raymarch(ro, rd, col, px);
				col = col * (1.0 - res.w) + res.xyz;

				// sun glare    
				col += 0.2 * float3(1.0, 0.4, 0.2) * pow(sun, 3.0);

				return float4(col, 1.0);
			}

            fixed4 frag (v2f i) : SV_Target
            {
				//float2 p = (-iResolution.xy + 2.0 * fragCoord.xy) / iResolution.y;
				float2 p = (-_ScreenParams.xy + 2.0 * (i.uv*_ScreenParams.xy)) / _ScreenParams.y;

				float2 m = iMouse.xy / _ScreenParams.xy;// float2(0.0, 0.0);

				// camera
				float3 ro = 4.0 * normalize(float3(sin(3.0 * m.x), 0.4 * m.y, cos(3.0 * m.x)));
				float3 ta = float3(0.0, -1.0, 0.0);
				float3x3 ca = setCamera(ro, ta, 0.0);
				// ray
				//float3 rd = ca * normalize(float3(p.xy,1.5));
				float3 rd = mul(normalize(float3(p.xy, 1.5)), ca);

				//fragColor = render(ro, rd, ivec2(fragCoord - 0.5));
				return render(ro, rd, int2((i.uv * _ScreenParams.xy) - 0.5));
            }
            ENDCG
        }
    }
}
