////-----------------//
///**Pure Depth AO**///
//-----------------////

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Have fun,
// Jose Negrete AKA BlueSkyDefender
//
// Read the Orange Duck to understand and work on this shader. This shader is ment to be a AO playground.
// The Real goal is to add GI using the same code in here because they are related. Don't care if you cheat.
// As long as you learn. Thank you. 5dollars is 5dollars
// http://theorangeduck.com/page/pure-depth-ssao
//
// https://github.com/BlueSkyDefender/Depth3D
 ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "ReShade.fxh"

uniform float total_strength <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 5.0;
	ui_label = "total strength";
	ui_tooltip = "total strength Ammount";
	ui_category = "AO";
> = 1.0;

uniform int samples <
	ui_type = "drag";
	ui_min = 1; ui_max = 128;
	ui_label = "samples";
	ui_tooltip = "samples Ammount";
	ui_category = "AO";
> = 1;

uniform float base <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "base";
	ui_tooltip = "base Ammount";
	ui_category = "AO";
> = 0.0;

uniform float area <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "area";
	ui_tooltip = "area Ammount";
	ui_category = "AO";
> = 1.0;

uniform float falloff <
	ui_type = "drag";
	ui_min = 0.00001; ui_max = 2.00001;
	ui_label = "falloff";
	ui_tooltip = "falloff Ammount";
	ui_category = "AO";
> = 0.00001;

uniform float radius <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "radius";
	ui_tooltip = "radius Ammount";
	ui_category = "AO";
> = 0.007;

uniform float noise_amount <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "noise modifier";
	ui_tooltip = "noise amount";
	ui_category = "AO";
> = 0.007;

uniform int blur_amount <
	ui_type = "drag";
	ui_min = 0; ui_max = 1;
	ui_label = "blur";
	ui_tooltip = "blur amount";
	ui_category = "AO";
> = 1;

uniform float depth_map_adjust <
	ui_type = "drag";
	ui_min = 0.0; ui_max = 1.0;
	ui_label = "Depth Map Adjustment";
	ui_tooltip = "This allows for you to adjust the DM precision.\n"
				 "Adjust this to keep it as low as possible.\n"
				 "Default is 7.5";
	ui_category = "Depth Buffer";
> = 0.007;

uniform int Debug <
	ui_type = "combo";
	ui_items = "Off\0Depth\0AO\0Normal\0";
	ui_label = "Debug View";
	ui_tooltip = "View Debug Buffers.";
	ui_category = "Debug Buffer";
> = 0;

/////////////////////////////////////////////////////D3D Starts Here/////////////////////////////////////////////////////////////////
#define pix float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT)

texture BackBufferTex : COLOR;

sampler BackBuffer
	{
		Texture = BackBufferTex;
	};

texture2D AO_Out { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; MipLevels = 2;};
sampler2D AO_Info { Texture = AO_Out;};

texture2D AO_Blur_Tex {Height=BUFFER_HEIGHT; Width=BUFFER_WIDTH; Format=RGBA8;};
sampler2D AO_Blur_Sampler {Texture=AO_Blur_Tex;};

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
float2 GetCorrectDepth(float2 texcoord)
{
	float zBuffer = ReShade::GetLinearizedDepth(texcoord).x; //Depth Buffer
	zBuffer /= depth_map_adjust;
	return float2(zBuffer,smoothstep(-1,1,zBuffer)); //2nd Option Better detail on the near end..
}

//Normals from Depth
float3 GetNormalFromDepth(float2 texcoord) // Normals are offset a little bit fix it.
{ 
  const float2 offset1 = float2(0.0,pix.y);
  const float2 offset2 = float2(pix.x,0.0);
  
  float depth1 = GetCorrectDepth( texcoord + offset1).r;
  float depth2 = GetCorrectDepth( texcoord + offset2).r;
  
  float3 p1 = float3(offset1, depth1 - GetCorrectDepth(texcoord).x);
  float3 p2 = float3(offset2, depth2 - GetCorrectDepth(texcoord).x);
  
  float3 normal = cross(p1, p2);
  normal.z = -normal.z;
  
  return normalize(normal);
	// float3 offset = float3(BUFFER_PIXEL_SIZE, 0.0);
	// float2 posCenter = texcoord.xy;
	// float2 posNorth  = posCenter - offset.zy;
	// float2 posEast   = posCenter + offset.xz;

	// float3 vertCenter = float3(posCenter - 0.5, 1) * ReShade::GetLinearizedDepth(posCenter);
	// float3 vertNorth  = float3(posNorth - 0.5,  1) * ReShade::GetLinearizedDepth(posNorth);
	// float3 vertEast   = float3(posEast - 0.5,   1) * ReShade::GetLinearizedDepth(posEast);

	// return -normalize(cross(vertCenter - vertNorth, vertCenter - vertEast)) * 0.5 + 0.5;
}

float rand2dTo1d(float2 value, float2 dotDir){
	float2 smallValue = sin(value);
	float random = dot(smallValue, dotDir);
	random = frac(sin(random) * 143758.5453);
	return random;
}

float3 rand2dTo3d(float2 value){
	return float3(
		rand2dTo1d(value, float2(12.989, 78.233)),
		rand2dTo1d(value, float2(39.346, 11.135)),
		rand2dTo1d(value, float2(73.156, 52.235))
	);
}

float rand3dTo1d(float3 value, float3 dotDir){
	//make value smaller to avoid artefacts
	float3 smallValue = sin(value);
	//get scalar value from 3d vector
	float random = dot(smallValue, dotDir);
	//make value more random by making it bigger and then taking the factional part
	random = frac(sin(random) * 143758.5453);
	return random;
}

float3 rand3dTo3d(float3 value){
	return float3(
		rand3dTo1d(value, float3(12.989, 78.233, 37.719)),
		rand3dTo1d(value, float3(39.346, 11.135, 83.155)),
		rand3dTo1d(value, float3(73.156, 52.235, 9.151))
	);
}
float rand1(float n)  { return frac(sin(n) * 43758.5453123); }
float4 SSAO(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{    
	float3 noise = rand2dTo3d(normalize(float2(texcoord.x, texcoord.y))) * noise_amount;
	float3 random =  saturate(noise);
  
	float depth = GetCorrectDepth(texcoord).x;
 
	float3 pos = float3(texcoord.xy, depth);
	float3 normal = GetNormalFromDepth( texcoord);
  
	float radius_depth = radius/depth;
	float4 occlusion = 0;

	float3 sample_sphere = float3( rand1(5.55381124), rand1(0.1812356),rand1(-0.43515519));
	float weight = 1;

  	for(int i=0; i < samples; i++) {
		sample_sphere = (rand3dTo3d(sample_sphere));
		float3 ray = radius_depth * reflect(sample_sphere, random);
		float3 hemi_ray = pos + sign(dot(ray,normal)) * ray;
		
		float occ_depth = GetCorrectDepth(saturate(hemi_ray.xy)).x;
		float difference = depth - occ_depth;
		//Implament your own Z THICCness with area
		occlusion += step(falloff, difference) * (1-smoothstep(falloff, area, difference));

  
  }
  
	float ao = 1 - occlusion.w * rcp(samples) * total_strength;
  
  //float3 gi = occlusion.rgb * rcp(samples);
  //return float4(gi,saturate(ao));
 
 	return saturate(ao + base);
}

float3 BlurPass1(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{
    float3 ao = tex2D(AO_Info, texcoord).rgb;       //shouldn't be visibile in reshade textures

    float offset[4] = { 0.0, 1.1824255238, 3.0293122308, 5.0040701377 };
    float weight[4] = { 0.39894, 0.2959599993, 0.0045656525, 0.00000149278686458842 };
	ao *= weight[0];
    for (int i = 1; i < 4; i++){

        ao += tex2D(AO_Info, texcoord  + float2( offset[i] * ReShade::PixelSize.y, 0) ).rgb  *weight[i];
        ao += tex2D(AO_Info, texcoord  - float2( offset[i] * ReShade::PixelSize.y, 0) ).rgb  *weight[i];

    }

    return  saturate(ao);
}

float4 Blur(float2 texcoords) // Do blur here
{ 	
	return tex2Dlod(AO_Blur_Sampler, float4(texcoords,0,blur_amount)).rgba;                     
}

float3 AO(float2 texcoords)
{

	float3 ao;
	switch(Debug){
		case 0:
      		ao = tex2D(BackBuffer, texcoords).rgb * Blur(texcoords).w;
			break;
		case 1: 
      		ao = GetCorrectDepth(texcoords).x;
			break;
		case 2: 
      		ao = Blur(texcoords).w;  
			break;
		case 3: 
			ao = GetNormalFromDepth(texcoords);
			break;
	}

	return ao;
}

float3 Out(float4 position : SV_Position, float2 texcoord : TEXCOORD) : SV_Target
{ 
	float3 Color = AO(texcoord).rgb;
	return Color;
}


//*Rendering passes*//

technique PDAO_MOD
< ui_tooltip = "Info : PureDepth AO Robloxian the Motion blurer.... and Pao the best PowerShell Scripter around."; >
{
	
		pass SSAO
	{
		VertexShader = PostProcessVS;
		PixelShader = SSAO;
		RenderTarget = AO_Out;
	}
		pass BlurPass1
	{
		VertexShader = PostProcessVS;
		PixelShader = BlurPass1;
		RenderTarget = AO_Blur_Tex;
	}

	pass Done
	{
		VertexShader = PostProcessVS;
		PixelShader = Out;
	}

}
