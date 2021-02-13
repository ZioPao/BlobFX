#include "ReShade.fxh"

////TEST SHADERS


//Parameters

uniform int num_of_samples = 3;
uniform float ray_length = 2;
uniform float rad = 0.45f;
uniform float ao_strength = 2f;
uniform float distance = 0.5f;      //ok
uniform float blend = 0.1f;


//Structs
struct BSAO_S{
    uint id : SV_VERTEX_ID;         //id of the current vertex
    float4 vpos : SV_POSITION;      //Screen Space Coordinates
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
    BSAO_S bsao;

	bsao.texcoord.x = (id == 2) ? 2.0 : 0.0;
	bsao.texcoord.y = (id == 1) ? 2.0 : 0.0;
	bsao.vpos = float4(bsao.texcoord.xy * float2(2, -2) + float2(-1, 1), 0, 1);


    return bsao;
};

//////////////////////////////////////////////////////
/* Pixel Shaders*/
//////////////////////////////////////////////////////

void BufferPreparationPass_PS(in BSAO_S bsao, out float4 back_buffer : SV_TARGET0, out float4 depth : SV_TARGET1, out float4 normal : SV_TARGET2)
{
    back_buffer = tex2D(ReShade::BackBuffer, bsao.texcoord.xy).rgba;
    depth = ReShade::GetLinearizedDepth(bsao.texcoord.xy).rrrr;
    normal = GetScreenSpaceNormal(bsao.texcoord.xy).rgb;
    

}

/* Check distance for the depth and then discards it if it exceeds it */
void DepthDistancePass_PS(in BSAO_S bsao, out float4 corrected_depth : SV_TARGET0){

    float temp_depth = tex2D(sampler_tex_depth, bsao.texcoord.xy).r;

    if (temp_depth > distance){
        discard;
    }
    corrected_depth = 1;
}

void AoPreparationPass_PS(in BSAO_S bsao, out float4 ao : SV_TARGET0){

    //Calculate near points in the normal and search for collisions
    static const float3 samples[3] =
    {
        //Closer and then more distant
        float3(0.9958, -0.853, -0.434),
        float3(-0.5152, +0.41248, 0.503),
        float3(0.34, 0.123, 0.552),
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

    ao = 0;

    float3 current_pos = bsao.vpos.xyz;



    float depth = tex2D(sampler_tex_depth, bsao.texcoord.xy).r;

    float3 p = (depth/bsao.vpos.z)*bsao.vpos;

    float4 normal = tex2D(sampler_tex_normal, bsao.texcoord.xy);

    //First check to eliminate the sky or sup like that
    if (normal.a < 1){

        //check on the normal with a "random" ray
        for (int i = 0; i < num_of_samples; i++){
            float3 ray = samples[i] - 3;
            //ray = dot(ray, float3(-0.5f,-0.5f,0.12f));
            ao += tex2D(sampler_tex_normal, -bsao.texcoord.xy + ray.xz).rrr;
        }

    }

    ao = p;

    
/*
    float3 corrected_depth = tex2D(sampler_tex_corrected_depth, bsao.texcoord.xy).rrr;
    float3 normal_fixed = corrected_depth - normal.rrr; 

    for (int i = 0; i < num_of_samples; i++){

        float4 sample_pos = float4(current_pos +samples[i], 1f);
        sample_pos.z = normal * sample_pos;
        sample_pos.xy /= sample_pos.w;
        sample_pos.xy = sample_pos.xy * 0.5 + float2(0.5f, 0.5f);
        float sample_depth = tex2D(sampler_tex_depth, sample_pos.xy).r;

        if (abs(bsao.vpos.z - sample_depth) < rad) {
            ao += step(sample_depth,sample_pos.z);
        }
        // float3 incident_ray = saturate(reflect(samples[i], normal_fixed) * ray_length);
        // float3 shitty_test = tex2D(sampler_tex_corrected_depth, (bsao.texcoord.xz * ReShade::PixelSize.x)  + incident_ray.xz).rrr;


        // // We need a random vector to reflect on
        // float3 ray = reflect(samples[i], normal_fixed);
        // float3 normal_result = dot(ray * ray_length, normal_fixed);
        // float z_result = saturate(corrected_depth - normal_fixed).z * ray.xyz;
        // temp_ao -= pow(normal_result, ao_strength);
       
    }

    ao = pow(ao,4).r;

*/
    //ao = 1;
   // ao.a = 1;
    // ao = pow(ao,ao_strength);
    // ao /= num_of_samples;
    // ao.a = 1;
}


void FinalPass_PS(in BSAO_S bsao, out float4 target : SV_TARGET){

    target = tex2D(sampler_tex_backbuffer, bsao.texcoord.xy);
    // float ao = tex2D(sampler_tex_ao, bsao.texcoord.xy).r;

    // //ao = pow(ao.rgb, 1.2);
    
    // target.rgb = saturate(lerp(target.rgb, -saturate(ao.r), blend));


}

technique BSAO2 {

    pass{
        VertexShader = BSAO_VS;
        PixelShader = BufferPreparationPass_PS;
        RenderTarget0 = tex_backbuffer;
        RenderTarget1 = tex_depth;
        RenderTarget2 = tex_normal;
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

    // pass{
    //     VertexShader = BSAO_VS;
    //     PixelShader = FinalPass_PS;

    // }
}