Shader "Custom/StochasticTextureRefactor"
{
    Properties
    {
        _TintColor ("Tint Color", Color) = (1,1,1,1)
        _BaseMap ("Base Map", 2D) = "white" {}
        _NormalTex ("Normal Map", 2D) = "bump" {}
        _NormalIntensity ("Normal Intensity", Float) = 1
        _GlossMap ("Gloss Map", 2D) = "white" {}
        _MetallicMap ("Metallic Map", 2D) = "white" {}
        _Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        _OcclusionMap ("Occlusion Map", 2D) = "white" {}
        _EmissionMap ("Emission Map", 2D) = "black" {}
        _EmissionColor ("Emission Color", Color) = (0,0,0)
        [Toggle]_UseStochastic("Enable Stochastic", Float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        #pragma exclude_renderers gles
        #pragma surface surf Standard fullforwardshadows
        #pragma target 3.0

        fixed4 _TintColor;

        sampler2D _BaseMap;
        sampler2D _NormalTex;
        sampler2D _GlossMap;
        sampler2D _MetallicMap;
        sampler2D _OcclusionMap;
        sampler2D _EmissionMap;

        float _NormalIntensity;
        float _Metallic;
        float _Smoothness;
        fixed4 _EmissionColor;
        float _UseStochastic;

        struct Input
        {
            float2 uv_BaseMap;
        };

        UNITY_INSTANCING_BUFFER_START(Props)
        UNITY_INSTANCING_BUFFER_END(Props)

        float2 Random2D(float2 uv)
        {
            return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
        }

        float4 SampleStochasticTexture(sampler2D tex, float2 uv)
        {
            float2x2 gridTransform = float2x2(1.0, 0.0, -0.57735027, 1.15470054);
            float2 gridUV = mul(gridTransform, uv * 3.464);

            float2 cell = floor(gridUV);
            float3 bary = float3(frac(gridUV), 0);
            bary.z = 1.0 - bary.x - bary.y;

            float4x3 verts = bary.z > 0 ?
                float4x3(float3(cell, 0), float3(cell + float2(0, 1), 0), float3(cell + float2(1, 0), 0), bary.zyx) :
                float4x3(float3(cell + float2(1, 1), 0), float3(cell + float2(1, 0), 0), float3(cell + float2(0, 1), 0), float3(-bary.z, 1.0 - bary.y, 1.0 - bary.x));

            float2 dx = ddx(uv);
            float2 dy = ddy(uv);

            return tex2D(tex, uv + Random2D(verts[0].xy), dx, dy) * verts[3].x +
                   tex2D(tex, uv + Random2D(verts[1].xy), dx, dy) * verts[3].y +
                   tex2D(tex, uv + Random2D(verts[2].xy), dx, dy) * verts[3].z;
        }

        void surf(Input IN, inout SurfaceOutputStandard o)
        {
            float4 baseColor;
            float4 normalSample;
            float4 glossSample;
            float4 metallicSample;
            float4 occlusionSample;
            float4 emissionSample;

            if (_UseStochastic)
            {
                baseColor = SampleStochasticTexture(_BaseMap, IN.uv_BaseMap);
                normalSample = SampleStochasticTexture(_NormalTex, IN.uv_BaseMap);
                glossSample = SampleStochasticTexture(_GlossMap, IN.uv_BaseMap);
                metallicSample = SampleStochasticTexture(_MetallicMap, IN.uv_BaseMap);
                occlusionSample = SampleStochasticTexture(_OcclusionMap, IN.uv_BaseMap);
                emissionSample = SampleStochasticTexture(_EmissionMap, IN.uv_BaseMap);
            }
            else
            {
                baseColor = tex2D(_BaseMap, IN.uv_BaseMap);
                normalSample = tex2D(_NormalTex, IN.uv_BaseMap);
                glossSample = tex2D(_GlossMap, IN.uv_BaseMap);
                metallicSample = tex2D(_MetallicMap, IN.uv_BaseMap);
                occlusionSample = tex2D(_OcclusionMap, IN.uv_BaseMap);
                emissionSample = tex2D(_EmissionMap, IN.uv_BaseMap);
            }

            o.Albedo = baseColor.rgb * _TintColor.rgb;
            o.Normal = UnpackScaleNormal(normalSample, _NormalIntensity);
            o.Metallic = metallicSample.r * _Metallic;
            o.Smoothness = glossSample.r * _Smoothness;
            o.Occlusion = occlusionSample.r;
            o.Emission = emissionSample.rgb * _EmissionColor.rgb;
            o.Alpha = baseColor.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
