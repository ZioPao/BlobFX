#include "ReShade.fxh"

////TEST SHADERS


//Parameters

uniform int num_of_samples = 2;
//uniform float g_surface_epsilon = 1f;
uniform float bias = 1f;
uniform float gOcclusionFadeEnd = 100;
////uniform float gOcclusionFadeStart = 0;
// uniform float noise_amount = 1f;
uniform float radius = 1f;
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


float3 PseudoRandomVec(float3 coord){


    float x = frac(sin(dot(coord.x, float2(12.9898, 78.233))) * 43758.5453);
    float y = frac(sin(dot(coord.y, float2(12.9898, 78.233))) * 43758.5453);
    float z = frac(sin(dot(coord.z, float2(12.9898, 78.233))) * 43758.5453);

    return saturate(float3(x, y, z));



}
// Determines how much the sample point q occludes the point p as a function
// of distZ.
float OcclusionFunction(float distZ)
{
	//
	// If depth(q) is "behind" depth(p), then q cannot occlude p.  Moreover, if 
	// depth(q) and depth(p) are sufficiently close, then we also assume q cannot
	// occlude p because q needs to be in front of p by Epsilon to occlude p.
	//
	// We use the following function to determine the occlusion.  
	// 
	//
	//       1.0     -------------\
	//               |           |  \
	//               |           |    \
	//               |           |      \ 
	//               |           |        \
	//               |           |          \
	//               |           |            \
	//  ------|------|-----------|-------------|---------|--> zv
	//        0     Eps          z0            z1        
	//
	
	float occlusion = 0.0f;
	//if(distZ > g_surface_epsilon)
	{
	//	float fadeLength = gOcclusionFadeEnd - gOcclusionFadeStart;
		
		// Linearly decrease occlusion from 1 to 0 as distZ goes 
		// from gOcclusionFadeStart to gOcclusionFadeEnd.	
	//	occlusion = saturate( (gOcclusionFadeEnd-distZ)/fadeLength );
	}
	
	return occlusion;	
}
float3 get_position_from_uv_mipmapped(in float2 uv, in BSAO_S bsao, in int miplevel)
{
    float3 uvtoviewADD = float3(-1.0,-1.0,1.0);
    float3 uvtoviewMUL = float3(2.0,2.0,0.0);
    return (uv.xyx * uvtoviewMUL + uvtoviewADD) * tex2Dlod(sampler_tex_depth, float4(uv.xyx, miplevel)).x;
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
 
       float3 samples[6] = {float3(0.01521, 0.12447, 0.09449),
                        float3(0.03491, 0.04310, 0.01063),
                        float3(0.07913, 0.04670, 0.07554),
                        float3(0.29996, 0.08449, 0.10183),
                        float3(0.18446, 0.25253, 0.03900),
                        float3(0.03799, 0.09218, 0.15440),};   


    /* float3 samples[6] = {float3(0,1f,0),
                            float3(-1f,0,0),
                            float3(0f,0f,1f),
                            float3(-1f,1f,1f),
                            float3(1f,0,1f),
                            float3(1f,1f,0f)}; 
 */

    
    ////////////////////////////////////////////////////////
    float ao = 0;


    //////////////////////////////////////////////////////////
    //Get normal from the texcoord
    ////////////////////////////////////////////////////////

    float3 normal = tex2D(sampler_tex_normal, bsao.texcoord);

    //Samples are used to cast "rays"


    for (int i = 0; i < num_of_samples; i++){

        float2 sample_point_pos = (bsao.texcoord.xy + samples[i].xy);
        float2 sample_point_neg = (bsao.texcoord.xy - samples[i].xy);

        //Check distance and angle


        float3 normal_mod = tex2D(sampler_tex_corrected_depth, normalize(sample_point_pos));


        if (normal.z < normal_mod.z + bias){
            ao++;
        }


    }
    ao /= num_of_samples;
    target = ao;



/*     //float3 samples[2] = {float3(0f,0f,0f), float3(0f,0.01f,0.0f)};

    float weigth[6] = {1f,0.9f,0.8f,0.7f,0.6f,0.5f};
    float horizontal_fov = vertical_fov * ReShade::AspectRatio;
    float PI = 3.14159265359f;
    float vertical_fov_rad = vertical_fov * PI/180;
    float horizontal_fov_rad = horizontal_fov * PI/180;
    float h, w, Q;

    w = (float)1/tan(horizontal_fov_rad*0.5);  // 1/tan(x) == cot(x)
    h = (float)1/tan(vertical_fov_rad*0.5);   // 1/tan(x) == cot(x)
    Q = z_far/(z_far - z_near);

    float4x4 proj_mat = float4x4(float4(w,0,0,0),
                            float4(0,h,0,0),
                            float4(0,0,Q,1),
                            float4(0,0, -Q*z_near,0));

    float3 position = tex2D(sampler_tex_depth, bsao.position.xy).rrr;
    float3 normal = tex2D(sampler_tex_normal, bsao.texcoord);

    float3 T , B, N; // Determine tangent s pac e
    float3 rvec = tex2D(sampler_tex_backbuffer, position.xy/2 * noise).xyz; // Picks random vector to orient the hemisphere
    float3 tangent = normalize(rvec - normal * dot(rvec, normal));
    float3 bitangent = cross(normal, tangent);
    float3x3 tbn = float3x3(tangent, bitangent, normal); // f: Tangent -> View space

    float ao = 0;
    float R = 2f;    

    for(int k = 0; k < num_of_samples; k++) {

        float3 sample_pos = mul(tbn, samples[k]) ;
        sample_pos = position.xyz + sample_pos * radius;

        float4 converted_sample_pos = float4(sample_pos.x, sample_pos.y, sample_pos.z, 0);
        converted_sample_pos = mul(proj_mat, converted_sample_pos);
        converted_sample_pos.xyz /= converted_sample_pos.w;
        converted_sample_pos.xyz = converted_sample_pos.xyz * 0.5 + 0.5;    // transform to range 0.0 - 1.0  

        float point_depth = tex2D(sampler_tex_depth, converted_sample_pos.xy).r;

        if (point_depth >= converted_sample_pos.z + bias ){
            ao++;
        }

    }

    ao /=num_of_samples; */

    


 /*    
    float samples[10] = {0.1f, 0.2f, 0.3f, 0.4f, 0.5f, 0.6f, 0.7f, 0.8f, 0.9f, 1.0f};
 */
  
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