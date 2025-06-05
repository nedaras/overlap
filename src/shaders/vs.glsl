cbuffer vertexBuffer : register(b0)
{
  float4x4 viewMatrix;
  float4x4 projectionMatrix;
};

struct VertexInput
{
  float3 position : POSITION;
  float2 uv : TEXCOORD0;
};

struct VertexOutput
{
  float4 position : SV_POSITION;
  float2 uv : TEXCOORD0;
};

VertexOutput VS(VertexInput input)
{
  VertexOutput output;
  float4x4 viewProjectionMatrix = mul(viewMatrix, projectionMatrix);
  output.position = mul(float4(input.position, 1.0f), viewProjectionMatrix);
  output.uv = input.uv;
  return output;
}
