#include "ReShade.fxh"

////TEST SHADERS


//Parameters

uniform int num_of_samples = 14;
uniform float ray_length = 2;
uniform float ao_strength = 2f;
uniform float distance = 1;
uniform float blend = 0.1f;
//Structs
struct BSAO_S{
    uint id : SV_VERTEX_ID;
    float4 vpos : SV_POSITION;
    float2 texcoord : TEXCOORD;     //Main one

};

//Constants
// static const float3 samples[14] =
// {       float3(1, 0, 0),
//         float3(	-1, 0, 0),
//         float3(0, 1, 0),
//         float3(0, -1, 0),
//         float3(0, 0, 1),
//         float3(0, 0, -1),
//         float3(1, 1, 1),
//         float3(-1, 1, 1),
//         float3(1, -1, 1),
//         float3(1, 1, -1),
//         float3(-1, -1, 1),
//         float3(-1, 1, -1),
//         float3(1, -1, -1),
//         float3(-1, -1, -1)
//      };         

//Samplers
texture2D tex_depth 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; };
sampler2D sampler_tex_depth {Texture=tex_depth;};

texture2D tex_corrected_depth 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; };
sampler2D sampler_tex_corrected_depth {Texture=tex_corrected_depth;};

texture2D tex_normal 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; };
sampler2D sampler_tex_normal {Texture=tex_normal;};

texture2D tex_backbuffer 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; };
sampler2D sampler_tex_backbuffer {Texture=tex_backbuffer;};

texture2D tex_ao 	{ Width = BUFFER_WIDTH;   Height = BUFFER_HEIGHT;   Format = RGBA8; };
sampler2D sampler_tex_ao {Texture=tex_ao;};

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

void BufferPreparationPass_PS(in BSAO_S BSAO, out float4 depth : SV_TARGET0, out float4 normal : SV_TARGET1, out float4 back_buffer : SV_TARGET2)
{


    normal = GetScreenSpaceNormal(BSAO.texcoord.xy).rgb;

    back_buffer = tex2D(ReShade::BackBuffer, BSAO.texcoord);

    depth = ReShade::GetLinearizedDepth(BSAO.texcoord).rrr;
    depth.a = 1;

}

void DepthDistancePass_PS(in BSAO_S bsao, out float4 corrected_depth : SV_TARGET0){

    float temp_depth = tex2D(sampler_tex_depth, bsao.texcoord).r;

    if (temp_depth > distance){
        discard;
    }
    corrected_depth = 1;


    


}

void AoPreparationPass_PS(in BSAO_S bsao, out float4 ao : SV_TARGET0){

    //Calculate near points in the normal and search for collisions
    static const float3 samples[1] =
    {
        //Closer and then more distant
        float3(1, 1, 1),
        //  float3(	0.22, 0.22, 0.22),
        //  float3(0.33, 0.33, 0.33),
        // float3(0.152, -0.231, -0.124),
        // float3(0.21, -0.75, 1),
        // float3(-0.14, 0.54, -0.021),
        // normalize(float3(0.5, 0.2, -1.1)),
        // normalize(float3(-1, 1, 1)),
        // normalize(float3(1, -1, 1)),
        // normalize(float3(1, 1, -1)),
        // normalize(float3(-1, -1, 1)),
        // normalize(float3(-1, 1, -1)),
        // normalize(float3(1, -1, -1)),
        // normalize(float3(-1, -1, -1))
    };



    static const float2 mul_dot = float2(2,2);
    ao = 0;
    float temp_ao = 0;

    float3 normal = tex2D(sampler_tex_normal, bsao.texcoord).rgb;
    float corrected_depth = tex2D(sampler_tex_corrected_depth, bsao.texcoord);
    float3 normal_fixed = corrected_depth.rrr - normal.rgb; 

    for (int i = 0; i < num_of_samples; i++){
        

        // We need a random vector to reflect on

        //float3 ray = reflect(samples[i] * ray_length, (normalize(normal_fixed))) ;
        float3 ray = reflect(samples[i], normal_fixed);
        //Calculate how far the ray hits

        float ray_mod = dot(ray, ray_length);
        float z_result = saturate(corrected_depth - normal_fixed).z * ray_mod;
        //float z_depth = saturate(distance * (corrected_depth - normal_fixed).x);



        temp_ao += pow(z_result, ao_strength);
        //temp_ao += saturate(pow(1-z_depth, ao_strength) + z_depth);
        //float2 ray = reflect(samples[i].xz, normalize(normal_fixed.xy)) * ray_length;
        //float2 ray2 = dot(samples[i].xy, float2(1.1,1.5));
        // float2 corrected_coords = (bsao.texcoord.xy * ReShade::PixelSize.xy) + ray;
        // temp_ao += (tex2D(sampler_tex_depth, corrected_coords).rrr - normal.rgb); 
    }

    ao = temp_ao/num_of_samples;
    ao.a = 1;

    // temp_ao = pow(temp_ao, ao_strength);
    // temp_ao /= num_of_samples;
    // ao = saturate(temp_ao);
    // ao.a = 1;
    
    //float3 modded_normal = ReShade::GetLinearizedDepth(bsao.texcoord) * RESHADE_DEPTH_LINEARIZATION_FAR_PLANE;;
    //ao = modded_normal;

    //we need to limit the normal map



}


void FinalPass_PS(in BSAO_S bsao, out float4 target : SV_TARGET){

    target = tex2D(sampler_tex_backbuffer, bsao.texcoord);
    float3 ao = tex2D(sampler_tex_ao, bsao.texcoord);

    //ao = pow(ao.rgb, 1.2);
    
    target.rgb = saturate(lerp(target.rgb, -saturate(ao.rgb), blend));


}

// void AORendering_PS(in BSAO_S BSAO, out float4 ao : SV_TARGET0){

//     //Using the normals, we're gonna need to read wheter or not there are "collisions" within near objects


//     //todo generate random samples

//     float3 normal = tex2D(samplerNormal, BSAO.texcoord.xy).xyz * 2.0 - 1.0;         //same here
//     float3 depth = tex2D(samplerDepth, BSAO.texcoord);
    
//     ao = 0;
//     float3 position_to_check = tex2D(samplerDepth, BSAO.texcoord.xy).x;      //Not sure why xyx in MXAO, so let's just try this crap
//     position_to_check += normal * depth;

//     float sample_jitter;
//     sample_jitter = 0.12f;
//     float2 sample_dir;
//     //sincos(2.3999632 * 16 * sample_jitter, sample_dir.x, sample_dir.y); //2.3999632 * 16
//     sample_dir.x = 0.01f;
//     sample_dir.y = 0f;
//     sample_dir *= 7;       //x radius

//     float2 texcoord_to_check = BSAO.texcoord.xy + sample_dir.xy;

//     //This is where the magic begins
//     float3 delta_v = - position_to_check + tex2D(samplerDepth, texcoord_to_check.xy).x;              
//     float v2 = dot(delta_v,delta_v);
//     float vn = dot(delta_v, normal) * rsqrt(v2);

//     ao.a += vn;       //Should be equal to color.a

//     // ao = 0;
//     // ao.rgb += position_to_check;
//     // ao.a = 1;

//     // for (int i = 0; i < 14; i++){
//     //     float3 ray = farCorner * float3(sign(BSAO.vpos.xy), 1);  //Got from Stuntrally repo

//     //     float3 randN = tex2D(samplerNormal, BSAO.texcoord * 24).xyz * 3.0 - 1.0;

//     //     float3 randomDir = reflect(samples[i], randN.xyz) + normal;
//     //     float4 nuv = float4(BSAO.vpos.xyz + randomDir * radius, 1);
//     //     nuv.xy /= nuv.w;
//     //     float zd = saturate(distance * (depth - tex2D(samplerNormal, nuv.xy).x));

//     //     ao += zd;

//     // }
//     // ao /= 14;


//     // ao = lerp(ao, float4(1,1,1,1), 0.5f);
//    // ao.rgb = depth.rgb;
// }




// void BSAO_PS (in BSAO_S BSAO, out float4 color : SV_TARGET0)
// {

//     color = tex2D(ReShade::BackBuffer, BSAO.texcoord.xy);

//     float3 ray = farCorner * float3(sign(BSAO.vpos.xy), 1);  //Got from Stuntrally repo
//     float3 randN = tex2D(samplerRandomNormal, BSAO.texcoord * 24).xyz * 2.0 - 1.0;
    

//     float4 ao = tex2D(samplerAO, BSAO.texcoord);

//     // if (BSAO.texcoord.x > 0.5f){
//     //     //Gets depth
//     //     float4 depth = ReShade::GetLinearizedDepth(BSAO.texcoord);
//     //     color.rgb = depth.rrr;
//     // } 

//     // return color;
// }
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


technique BSAO2 {

    pass{
        VertexShader = BSAO_VS;
        PixelShader = BufferPreparationPass_PS;
        RenderTarget0 = tex_depth;
        RenderTarget1 = tex_normal;
        RenderTarget2 = tex_backbuffer;
    }
    pass{
        VertexShader = BSAO_VS;
        PixelShader = DepthDistancePass_PS;
        RenderTarget0 = tex_corrected_depth;
        ClearRenderTargets = true;      //Needed to clear stuff in tex_corrected_depth
		
    }
    pass{
        VertexShader = BSAO_VS;
        PixelShader = AoPreparationPass_PS;
        RenderTarget0 = tex_ao;
    } 

    pass{
        VertexShader = BSAO_VS;
        PixelShader = FinalPass_PS;

    }
}