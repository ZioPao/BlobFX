#include "ReShade.fxh"
#define SAMPLE_COUNT 6


//Structs

struct GB_S{
    float4 vpos : SV_POSITION;
    float2 texcoord : TEXCOORD;

};




//Samplers


texture2D colorTex { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT; Format = RGBA8;};

sampler2D TrilinearSampler
{
    //Filter = MIN_MAG_MIP_LINEAR;
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
    Texture=colorTex;
};

texture2D tempBlurPass { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT; Format = RGBA8;};
sampler2D samplerBlurPass{Texture=tempBlurPass;};
// texture2D texColorBuffer { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT; Format = RGBA8;};

// texture2D texDepthBuffer	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;};
// sampler2D samplerDepth{ Texture = texDepthBuffer;};

// texture2D texAoBuffer 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8;};
// sampler2D samplerAO {Texture = texAoBuffer;};

// texture2D texNormalBuffer 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8;};
// sampler2D samplerNormal {Texture = texNormalBuffer;};

// texture2D texRandomNormal { Width = BUFFER_WIDTH/4;   Height = BUFFER_HEIGHT/4;   Format = RGBA8;};
// sampler2D samplerRandomNormal {Texture = texRandomNormal;};

//////////////////////////////////////////////////////
//Helper methods//
//////////////////////////////////////////////////////
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


//////////////////////////////////////////////////////
/* Vertex Shaders*/
//////////////////////////////////////////////////////

void GB_VS( in uint id : SV_VERTEX_ID, out GB_S gb){

    gb.texcoord.x = (id == 2) ? 2.0 : 0.0;
    gb.texcoord.y = (id == 1) ? 2.0 : 0.0;
    gb.vpos = float4(gb.texcoord * float2(2.0, -2.0) + float2(-1.0, 1.0), 0.0, 1.0);

}


//////////////////////////////////////////////////////
/* Pixel Shaders*/
//////////////////////////////////////////////////////

void First_Pass_PS(in GB_S gb, out float4 color : SV_TARGET0){


    float2 sample_offset[SAMPLE_COUNT];
    float sample_weight[SAMPLE_COUNT];


   // color = tex2D(ReShade::BackBuffer, gb.texcoord);

     for (int i = 0; i < SAMPLE_COUNT; i++){
        color -= tex2D(TrilinearSampler, gb.texcoord + sample_offset[i]*sample_weight[i]);
     }


}








/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


technique GaussianBlurTest {

    pass{
        VertexShader = PostProcessVS;
        PixelShader = First_Pass_PS;
        RenderTarget0 = colorTex;
    }

    
}