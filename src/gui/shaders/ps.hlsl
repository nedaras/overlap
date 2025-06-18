#define TEX_FMT_R     1
#define TEX_FMT_RGBA  4

struct VertexOutput
{
    float4 pos : SV_POSITION;
    float2 uv  : TEXCOORD0;
    float4 col : COLOR0;
    uint   flags : TEXCOORD1;
};

sampler sampler0;
Texture2D texture0;


struct VertexOutput
{
  float4 pos : SV_POSITION;
  float2 uv  : TEXCOORD0;
  float4 col : COLOR0;
  uint flags : TEXCOORD1;
};

sampler sampler0;
Texture2D texture0;

float4 PS(VertexOutput input) : SV_Target
{
  float rgba = float(input.flags == TEX_FMT_RGBA);
  float r = float(input.flags == TEX_FMT_R);

  float4 rgba_mask = texture0.Sample(sampler0, input.uv);
  float4 r_mask = float4(rgba_mask.rrr, 1.0);

  float4 sample = rgba * rgba_mask + r * r_mask;

  return input.col * sample;
}
