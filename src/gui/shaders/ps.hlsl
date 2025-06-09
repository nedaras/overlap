struct VertexOutput
{
  float4 pos : SV_POSITION;
  float4 col : COLOR0;
};

float4 PS(VertexOutput input) : SV_Target
{
  return input.col;
}
