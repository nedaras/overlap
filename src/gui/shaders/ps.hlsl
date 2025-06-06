struct VertexOutput
{
  float4 pos : SV_POSITION;
  float3 color : COLOR0;
};

float4 PS(VertexOutput input) : SV_Target
{
  return float4(input.color, 1.0);
}
