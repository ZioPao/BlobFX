#include "ReShade.fxh"

uniform int strength = 0.1;       //max

texture2D blur_tex {Height=BUFFER_HEIGHT; Width=BUFFER_WIDTH; Format=RGBA8;};
sampler2D blur_sampler {Texture=blur_tex;};

void BlurPass1_PS(in float2 texcoord : TEXCOORD, out float3 color : SV_TARGET0){

    color = tex2D(ReShade::BackBuffer, texcoord).rgb;       //shouldn't be visibile in reshade textures

    float offset[4] = { 0.0, 1.1824255238, 3.0293122308, 5.0040701377 };
    float weight[4] = { 0.39894, 0.2959599993, 0.0045656525, 0.00000149278686458842 };
	color *= weight[0];
    for (int i = 1; i < 4; i++){

        color += tex2D(ReShade::BackBuffer, texcoord  + float2( offset[i] * ReShade::PixelSize.y, 0) ).rgb  *weight[i];
        color += tex2D(ReShade::BackBuffer, texcoord  - float2( offset[i] * ReShade::PixelSize.y, 0) ).rgb  *weight[i];

    }

    color = saturate(color);



}


void BlurPass2_PS(in float2 texcoord : TEXCOORD, out float3 color : COLOR){

    float3 original_color = tex2D(ReShade::BackBuffer, texcoord).rgb;
    float3 blur = tex2D(blur_sampler, texcoord).rgb;


    float offset[4] = { 0.0, 1.1824255238, 3.0293122308, 5.0040701377 };
    float weight[4] = { 0.39894, 0.2959599993, 0.0045656525, 0.00000149278686458842 };
    
    blur *= weight[0];

   // blur -= 0.5f;
    for (int i = 1; i < 4; i++){

        blur += tex2D(blur_sampler, texcoord  + float2( offset[i] * ReShade::PixelSize.y, 0) ).rgb  *weight[i];
        blur += tex2D(blur_sampler, texcoord  - float2( offset[i] * ReShade::PixelSize.y, 0) ).rgb  *weight[i];

    }
   // color = lerp (original_color, blur, strength);
    color = lerp(original_color, blur, strength);
    color = saturate(color);


    //color = saturate(lerp(tex2D(blur_sampler, texcoord).rgb, ),0.1f);
}


technique GaussBlur {
    pass{
        VertexShader = PostProcessVS;
        PixelShader = BlurPass1_PS;
        RenderTarget = blur_tex;
    }
    pass{
        VertexShader = PostProcessVS;
        PixelShader = BlurPass2_PS;
    }
}