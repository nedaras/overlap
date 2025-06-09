struct VertexOutput
{
  float4 pos : SV_POSITION;
  float2 uv  : TEXCOORD0
  float4 col : COLOR0;
};

float4 PS(VertexOutput input) : SV_Target
{
  return input.col;
}
