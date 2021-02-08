#include "ReShade.fxh"
///Params

uniform int sample_count = 2;
texture2D CommonTex0 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; };


///Helpers Methods

struct BSAO_VSOUT
{
	float4                  vpos        : SV_Position;
    float4                  uv          : TEXCOORD0;
    // float4                  depth       : SV_TARGET0;
    // float3                  normal      : SV_TARGET1;

    //For now I've got no idea what this stuff actually does
    // nointerpolation float   samples     : TEXCOORD1;
    // nointerpolation float3  uvtoviewADD : TEXCOORD4;
    // nointerpolation float3  uvtoviewMUL : TEXCOORD5;
};



///NORMAL GENERATION
float3 GetScreenSpaceNormal(float2 texcoord)
{
	float3 offset = float3(BUFFER_PIXEL_SIZE, 0.0);
	float2 posCenter = texcoord.xy;
	float2 posNorth  = posCenter - offset.zy;
	float2 posEast   = posCenter + offset.xz;

	float3 vertCenter = float3(posCenter - 0.5, 1) * ReShade::GetLinearizedDepth(posCenter);
	float3 vertNorth  = float3(posNorth - 0.5,  1) * ReShade::GetLinearizedDepth(posNorth);
	float3 vertEast   = float3(posEast - 0.5,   1) * ReShade::GetLinearizedDepth(posEast);

	return normalize(cross(vertCenter - vertNorth, vertCenter - vertEast)) * 0.5 + 0.5;
}


///

// Vertex shader generating a triangle covering the entire screen
BSAO_VSOUT BSAO_VS(in uint id : SV_VertexID)
{
    BSAO_VSOUT BSAO;

    BSAO.uv.x = (id == 2) ? 2.0 : 0.0;
    BSAO.uv.y = (id == 1) ? 2.0 : 0.0;

	BSAO.vpos = float4(BSAO.uv * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    
    return BSAO;
}



void BSAO_PS(in BSAO_VSOUT BSAO, out float4 color : SV_TARGET0) 
{

    float3 depth = ReShade::GetLinearizedDepth(float2(BSAO.uv.x,BSAO.uv.y));
    float3 normal = GetScreenSpaceNormal(float2(BSAO.uv.x,BSAO.uv.y));

    // Random vector to generate "rays"

    float3 rand_vec = float3( 1f, 1f, 1f);
    float3 near_point = reflect(rand_vec, normal);


    color = tex2D(ReShade::BackBuffer, BSAO.uv.xy);
    color += near_point;
    color.w =  1;
    // for (int i = 0; i < sample_count; i++){

    // }

   // result = lerp(BSAO.vpos.xyz, near_point,0.5f);
    

}

technique BSAO {
    
    pass{
        VertexShader = BSAO_VS;
        PixelShader = BSAO_PS;
        
        RenderTarget = CommonTex0;
        ClearRenderTargets = true;
        StencilEnable = true;
        StencilPass = KEEP;
        StencilFunc = EQUAL;
        StencilRef = 1;
        
    }
}