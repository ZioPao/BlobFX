#include "ReShade.fxh"

////TEST SHADERS


//Parameters

uniform float3 farCorner = 1f;
uniform float radius = 0.2f;
uniform float distance = 100f;
//Structs

struct BSAO_S{
    uint id : SV_VERTEX_ID;
    float4 vpos : SV_POSITION;
    float2 texcoord : TEXCOORD0;

};





//Samplers
texture2D texColorBuffer { Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT; Format = RGBA8;};

texture2D texDepthBuffer	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;};
sampler2D samplerDepth{ Texture = texDepthBuffer;};

texture2D texAoBuffer 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8;};
sampler2D samplerAO {Texture = texAoBuffer;};

texture2D texNormalBuffer 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8;};
sampler2D samplerNormal {Texture = texNormalBuffer;};

texture2D texRandomNormal { Width = BUFFER_WIDTH/4;   Height = BUFFER_HEIGHT/4;   Format = RGBA8;};
sampler2D samplerRandomNormal {Texture = texRandomNormal;};

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

BSAO_S BSAO_VS(in uint id : SV_VertexID)
{
    BSAO_S BSAO;

	BSAO.texcoord.x = (id == 2) ? 2.0 : 0.0;
	BSAO.texcoord.y = (id == 1) ? 2.0 : 0.0;
	BSAO.vpos = float4(BSAO.texcoord * float2(2, -2) + float2(-1, 1), 0, 1);
    return BSAO;
};

//////////////////////////////////////////////////////
/* Pixel Shaders*/
//////////////////////////////////////////////////////

void BufferPreparation_PS(in BSAO_S BSAO, out float4 depth : SV_TARGET0, out float4 normal : SV_TARGET1, out float4 color : SV_TARGET2)
{



    depth = ReShade::GetLinearizedDepth(BSAO.texcoord).rrr;
    depth.a = 1;

    normal = GetScreenSpaceNormal(BSAO.texcoord.xy);
    normal.a = 1;

    color = tex2D(ReShade::BackBuffer, BSAO.texcoord);

}

void AORendering_PS(in BSAO_S BSAO, out float4 ao : SV_TARGET0){

    //Using the normals, we're gonna need to read wheter or not there are "collisions" within near objects
    float3 samples[14] =
    {
        float3(1, 0, 0),
        float3(	-1, 0, 0),
        float3(0, 1, 0),
        float3(0, -1, 0),
        float3(0, 0, 1),
        float3(0, 0, -1),
        normalize(float3(1, 1, 1)),
        normalize(float3(-1, 1, 1)),
        normalize(float3(1, -1, 1)),
        normalize(float3(1, 1, -1)),
        normalize(float3(-1, -1, 1)),
        normalize(float3(-1, 1, -1)),
        normalize(float3(1, -1, -1)),
        normalize(float3(-1, -1, -1))
    };         

    //todo generate random samples
    float3 ray = farCorner * float3(sign(BSAO.vpos.xy), 1);  //Got from Stuntrally repo
    float3 randN = tex2D(samplerRandomNormal, BSAO.texcoord * 24).xyz * 2.0 - 1.0;
    
    //Gets normal
    float3 normal = tex2D(samplerNormal, BSAO.texcoord);
    //Gets depth
    float3 depth = tex2D(samplerDepth, BSAO.texcoord);

    for (int i = 0; i < 4; i++){
        float3 randomDir = reflect(samples[i], randN) + normal;
        float4 nuv = float4(BSAO.vpos.xyz + randomDir * radius, 1);
        nuv.xy /= nuv.w;
        float zd = saturate(distance * (depth - tex2D(samplerNormal, nuv.xy).x));

        ao += saturate(pow(1 - zd, 3));
    }
   // ao.rgb = depth.rgb;
}




void BSAO_PS (in BSAO_S BSAO, out float4 color : SV_TARGET0)
{

    color = tex2D(ReShade::BackBuffer, BSAO.texcoord.xy);
    float4 ao = tex2D(samplerAO, BSAO.texcoord);
    color = lerp(color,ao,0.1f);

    // if (BSAO.texcoord.x > 0.5f){
    //     //Gets depth
    //     float4 depth = ReShade::GetLinearizedDepth(BSAO.texcoord);
    //     color.rgb = depth.rrr;
    // } 

    // return color;
}
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


technique BSAO2 {

    pass{
        VertexShader = BSAO_VS;
        PixelShader = BufferPreparation_PS;
        RenderTarget0 = texDepthBuffer;
        RenderTarget1 = texNormalBuffer;
        RenderTarget2 = texColorBuffer;
    }

    pass{
        VertexShader = BSAO_VS;
        PixelShader = AORendering_PS;
        RenderTarget0 = texAoBuffer;
    }

    pass{
        VertexShader = BSAO_VS;
        PixelShader = BSAO_PS;
    }
    
}