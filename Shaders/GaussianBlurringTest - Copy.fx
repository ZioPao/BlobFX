#include "ReShade.fxh"
#define SAMPLE_COUNT 15


//Samplers


texture2D colorTex { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT; Format = RGBA8;};

texture GaussianBlurTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler GaussianBlurSampler { Texture = GaussianBlurTex;};


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



//////////////////////////////////////////////////////
/* Pixel Shaders*/
//////////////////////////////////////////////////////

void First_Pass_PS(in float2 texcoord : TEXCOORD, out float4 color : SV_TARGET0){

    float offset[15] = { 0.0, 1.4953705027, 3.4891992113, 5.4830312105, 7.4768683759, 9.4707125766, 11.4645656736, 13.4584295168, 15.4523059431, 17.4461967743, 19.4401038149, 21.43402885, 23.4279736431, 25.4219399344, 27.4159294386 };
    float weight[15] = { 0.0443266667, 0.0872994708, 0.0820892038, 0.0734818355, 0.0626171681, 0.0507956191, 0.0392263968, 0.0288369812, 0.0201808877, 0.0134446557, 0.0085266392, 0.0051478359, 0.0029586248, 0.0016187257, 0.0008430913 };


    color = tex2D(GaussianBlurSampler, texcoord);
    color = lerp(tex2D(ReShade::BackBuffer, texcoord), color, 0.3f);

    //  for (int i = 0; i < SAMPLE_COUNT; i++){
    //     color *= tex2D(GaussianBlurSampler, gb.texcoord + offset[i]*weight[i]);
    //  }





}






/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


technique GaussianBlurTest {

    pass{
        VertexShader = PostProcessVS;
        PixelShader = First_Pass_PS;
        RenderTarget0 = GaussianBlurTex;
    }

    // pass{
    //     VertexShader = PostProcessVS;
    //     PixelShader = Second_Pass_PS;

    // }

    
}