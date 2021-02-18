#include "ReShade.fxh"

////TEST SHADERS


//Parameters

uniform int num_of_samples = 2;
//uniform float g_surface_epsilon = 1f;
uniform float bias = 1f;
uniform float gOcclusionFadeEnd = 100;
////uniform float gOcclusionFadeStart = 0;
// uniform float noise_amount = 1f;
uniform float ray_radius = 1f;
// uniform float ao_clamp = 0.125f;
// uniform float gauss_bell_center = 0.4f; //gauss bell center //0.4
// uniform float diff_area = 0.3f; //self-shadowing reduction
// // uniform float ray_length = 2;
// // uniform float rad = 0.45f;
// uniform float ao_strength = 2f;
uniform float strength = 1f;
uniform float occlusion_factor = 1f;
uniform float distance = 0.5f;      //ok
// uniform float blend = 0.1f;
uniform float lumInfluence = 0.7f; //how much luminance affects occlusion

uniform float noise = 1;

uniform float vertical_fov = 59f;



uniform float z_near = 1f;
uniform float z_far = 100f;

// uniform float bias = 0f;
//Structs
struct BSAO_S{

    /*It is a position in clip space in vertex shader and screen space position in pixel shader*/
    uint id : SV_VERTEX_ID;         //id of the current vertex
    float4 position : SV_POSITION;      //View space?
    float2 texcoord : TEXCOORD;     //texcoord = the currently processed pixel

        


};

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


float2 PseudoRandomVec(float2 coord){


    float x = frac(sin(dot(coord.x, float2(12.9898, 78.233))) * 43758.5453);
    float y = frac(sin(dot(coord.y, float2(12.9898, 78.233))) * 43758.5453);

    return saturate(float2(x, y));



}

//////////////////////////////////////////////////////
/* Vertex Shader*/
//////////////////////////////////////////////////////

BSAO_S BSAO_VS(in uint id : SV_VertexID)
{

    /* vpos is directly affected by texcoord, and so is 
    texcoord directly affected by vpos for some reasons */
    BSAO_S bsao;
    float2 madd=float2(0.5f,0.5f);

	bsao.texcoord.x = (id == 2) ? 2.0 : 0.0;
	bsao.texcoord.y = (id == 1) ? 2.0 : 0.0;

	bsao.position = float4(bsao.texcoord.xy * float2(2, -2) + float2(-1, 1) , 0, 1);
   //bsao.position.xy *=  madd + madd;

    return bsao;
};

//////////////////////////////////////////////////////
/* Pixel Shaders*/
//////////////////////////////////////////////////////

void BufferPreparationPass_PS(in BSAO_S bsao, out float4 back_buffer : SV_TARGET0, out float4 depth : SV_TARGET1, out float4 normal : SV_TARGET2)
{
    back_buffer = tex2D(ReShade::BackBuffer, bsao.texcoord.xy).rgba;
    depth.rgb = ReShade::GetLinearizedDepth(bsao.texcoord.xy).r;
    normal.rgb = GetScreenSpaceNormal(bsao.texcoord.xy).rgb;
    
}

/* Check distance for the depth and then discards it if it exceeds it */
void DepthDistancePass_PS(in BSAO_S bsao, out float4 corrected_depth : SV_TARGET0){

    float temp_depth = tex2D(sampler_tex_depth, bsao.texcoord.xy).r;
     if (temp_depth > distance){
         discard;
     }
     corrected_depth.rgb = temp_depth.rrr;
     corrected_depth.a = 1;
}

void AoPreparationPass_PS(in BSAO_S bsao, out float4 target : SV_TARGET0){




/*
1) Use texcoord as base to cast some samples starting from it
2) for each sample, check the depth and determines if ao is ++ or not
    Now, ao++ is a float4 and it doesn't make a lot of sense

*/
 
 //Values too low?
/*        float3 samples[7] = {float3(0.01521, 0.12447, 0.09449),
                        float3(0.03491, 0.04310, 0.01063),
                        float3(0.07913, 0.04670, 0.07554),
                        float3(0.19996, 0.08449, 0.10183),
                        float3(0.18446, 0.15253, 0.03900),
                        float3(0.03799, 0.09218, 0.15440),
                        float3(0.09713, 0.14170, 0.27554),};    */





    float2 samples[27] = {       
                            float2(0.00091, 0.000010),
                            float2(0.03491, 0.04310),
                            float2(0.07913, 0.04670),
                            float2(0.19996, 0.08449),
                            float2(0.18446, 0.15253),
                            float2(0.09713, 0.14170),
                            float2(0.90722, 0.92484),
                  
                            float2(1.1f, 2.1f),
                            float2(2.1f, 5.1f),
                            float2(2.5, 1.9f),
                            float2(6.13293, 5.75987),
                            float2(-1.65063, 9.29245),
                            float2(8.38166, 5.30451),
                            float2(0.03799, -0.09218),
                            float2(-6.44015, 3.41690),
                            float2(1.37779, -4.50609),
                            float2(0.01521, 0.12447),
                            float2(-0.03491, 0.04310),
                            float2(0.07913, -0.04670),
                            float2(0.19996, -0.08449),
                            float2(0.18446, 0.15253),
                            float2(-0.09713, 0.14170),
                            float2(0.90722, 7.92484),
                            float2(-7.61085, 8.64040),
                            float2(5.07657, 7.42778),
                            float2(11.29401, 10.41430),
                            float2(13.68830, 8.99593)};
    float weigth[7] = {1f,0.9f,0.8f,0.7f,0.6f,0.5f, 0.4f};


 
    ////////////////////////////////////////////////////////
    float ao = 0;


    //////////////////////////////////////////////////////////
    //Get normal from the texcoord
    ////////////////////////////////////////////////////////

    float3 normal = normalize(tex2D(sampler_tex_normal, bsao.texcoord));

    //Samples are used to cast "rays"


    for (int i = 0; i < num_of_samples; i++){
        
        
        float2 random_vec = PseudoRandomVec(bsao.texcoord) * ray_radius;
        //float2 scaled_sample = float2(samples[i].x * ReShade::PixelSize.x , samples[i].y * ReShade::PixelSize.y) ;
        float2 scaled_sample = float2(random_vec.x * ReShade::PixelSize.x , random_vec.y * ReShade::PixelSize.y) ;

        float2 sample_point_pos = (bsao.texcoord.xy + scaled_sample)  ;
        float2 sample_point_neg = (bsao.texcoord.xy - scaled_sample) * 1/(i+1) ;

        //Check distance and angle


        float3 first_normal_mod = (tex2D(sampler_tex_normal, sample_point_pos));
        float3 second_normal_mod = (tex2D(sampler_tex_depth, sample_point_neg));

        //todo need to check angle
        if (normal.z < first_normal_mod.z + bias){
            ao++;
        }
/*         if (normal.z > second_normal_mod.z + bias){
            ao++;
        } */


    }
    ao /= num_of_samples;
    target = pow(ao,strength);
  
}


void FinalPass_PS(in BSAO_S bsao, out float4 target : SV_TARGET){

    target = tex2D(sampler_tex_backbuffer, bsao.texcoord.xy);
    float ao = tex2D(sampler_tex_ao, bsao.texcoord.xy).r;
    float3 lumcoeff = float3(0.299,0.587,0.114);
    float lum = dot(target.rgb, lumcoeff);
    float3 luminance = float3(lum, lum, lum);

    // //This is the magic part
    float4 mixed_result = float4(lerp (float3(ao.rrr), float3(1,1,1), luminance*lumInfluence),1);
    target = target * mixed_result;

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
        StencilEnable = true;
		StencilPass = REPLACE;
        StencilRef = 1;
    } 
     pass{
        VertexShader = BSAO_VS;
        PixelShader = AoPreparationPass_PS;
        RenderTarget0 = tex_ao;
        StencilEnable = true;
		StencilPass = KEEP;
        StencilRef = 1;
     } 

      pass{
          VertexShader = BSAO_VS;
          PixelShader = FinalPass_PS;

      }
}