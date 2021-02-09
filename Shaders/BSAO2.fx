#include "ReShade.fxh"
///Params

uniform int sample_count = 2;
texture2D CommonTex0 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; };
sampler2D CommonTexSampler	{ Texture = CommonTex0;	};

texture2D ColorTex 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; MipLevels = 3;};
texture2D DepthTex 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = R16F;  MipLevels = 3;};
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


    // Random vector to generate "rays"
    color = tex2D(ReShade::BackBuffer, BSAO.uv.xy);
    depth = ReShade::GetLinearizedDepth(BSAO.uv.xy);
    normal = GetScreenSpaceNormal(BSAO.uv.xy);

    // }

   // result = lerp(BSAO.vpos.xyz, near_point,0.5f);
    

}

void AOPass_PS(in BSAO_VSOUT BSAO, out float4 color : SV_TARGET){


    float3 tempAO = (reflect(float3(1,1,1), GetScreenSpaceNormal(float2(BSAO.uv.x,BSAO.uv.y))));

    float4 tempAO2 = float4(tempAO.xyz, 1f);

    color *= (tempAO2);
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
        ClearRenderTargets = true;
		StencilEnable = true;
	    StencilPass = REPLACE;
        StencilRef = 1;
    }

     //Setup of various textures before hand
     pass{
         VertexShader = BSAO_VS;
         PixelShader = AOPass_PS;
        ClearRenderTargets = true;
		StencilEnable = true;
	    StencilPass = REPLACE;
        StencilRef = 1;
     }

    // pass{
    //     VertexShader = BSAO_VS;
    //     PixelShader = LastPass_PS;
    //     RenderTarget = CommonTex0;

    // }
}