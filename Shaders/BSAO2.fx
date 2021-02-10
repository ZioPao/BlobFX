#include "ReShade.fxh"
///Params

uniform float radius = 0.02f;
uniform int sample_count = 2;


//Samplers
texture2D CommonTex0 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; };
sampler2D CommonTexSampler	{ Texture = CommonTex0;	};

texture2D ColorTex 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; MipLevels = 3;};
texture2D DepthTex 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = R16F;  MipLevels = 3;};    //R16F determines wheter or not it's a depth thing
texture2D NormalTex	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; MipLevels = 3;};

sampler2D ColorTexSampler	{ Texture = ColorTex;	};
sampler2D DepthTexSampler	{ Texture = DepthTex;	};
sampler2D NormalTexSampler	{ Texture = NormalTex;	};

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

	BSAO.vpos = float4(BSAO.uv.xy * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);
    
    return BSAO;
}



void SetupMaps_PS(in BSAO_VSOUT BSAO, out float4 color : SV_TARGET0, out float4 depth : SV_TARGET1, out float4 normal : SV_TARGET2) 
{

    color = tex2D(ReShade::BackBuffer, BSAO.uv.xy);
    depth = ReShade::GetLinearizedDepth(BSAO.uv.xy);
    normal = GetScreenSpaceNormal(BSAO.uv.xy);
    

}


void StencilPass_PS(in BSAO_VSOUT BSAO, out float4 color : SV_TARGET0){

    color = 1;
}



void AOPass_PS(in BSAO_VSOUT BSAO, out float4 color : SV_TARGET){

    //Restores the original ColorTex
	color = tex2D(ColorTexSampler, BSAO.uv.xy);     
    float3 normal = GetScreenSpaceNormal(BSAO.uv.xy);


    //Calculate AO

    float3 ao = reflect(float3(0.1f,0.1f,0.1f), normal).r;      //Uses only r so it's grey-scaled

    color += ao;
   // float3 firstSample = float3(1, 0, 0),

    //float3 randomDir = reflect(, randN) + viewNorm;

    //float4 ao = 
    //Applies AO 

}
 void LastPass_PS(in BSAO_VSOUT BSAO, out float4 result : SV_TARGET){

     result = tex2D(CommonTexSampler, BSAO.uv.xy).rgb;

}   


technique BSAO2 {
    
    pass{
        VertexShader = BSAO_VS;
        PixelShader = SetupMaps_PS;
        RenderTarget0 = ColorTex;
        RenderTarget1 = DepthTex;
        RenderTarget2 = NormalTex;

    }

     //Setup of various textures before hand
     pass{
        VertexShader = BSAO_VS;
        PixelShader = StencilPass_PS;
        ClearRenderTargets = true;
		StencilEnable = true;
	    StencilPassOp = REPLACE;
        StencilRef = 1;
     }

    pass{
         VertexShader = BSAO_VS;
         PixelShader = AOPass_PS;
         //RenderTarget = CommonTex0;

     }
}