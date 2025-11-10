program HLM;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Horus.Shader.Raytracer in 'Horus.Shader.Raytracer.pas',
  Horus.Intersection in 'Horus.Intersection.pas',
  Mundus.Renderer,
  Mundus.Mesh,
  Mundus.Mesh.Loader,
  Mundus.Shader,
  Mundus.GeometryBuffer,
  Mundus.Math,
  Mundus.Mesh.Loader.FBX,
  Vcl.Graphics,
  System.Types,
  Mundus.Texture,
  Horus.SceneQuery in 'Horus.SceneQuery.pas',
  Horus.Types in 'Horus.Types.pas',
  System.IOUtils;

procedure Main;
var
  LRender: TMundusRenderer;
  LScene: TMeshGroup;
  LQuery: TSceneQuery;
  LBuffers: PGeometryBuffers;
  LBuffer: PGeometryBuffer;
  LMesh: TMesh;
  LShader: PShaderInfo;
  LLight: TFloat3;
  LTarget: TBitmap;
  i: Integer;
  LIndices: TArray<Integer>;
  LDebugMap: TTexture;
begin
  LShader := TShaders.Resolve(CTracerShader);
  LLight := Float3(116, 1200, -1400);
  LScene := TMeshLoaders.LoadFromFile(ParamStr(1), 1);
  LQuery := TSceneQuery.Create();
  LDebugMap := nil;
  if TFile.Exists('.\Debugmap.bmp') then
  begin
    LDebugMap := TTexture.Create();
    LDebugMap.LoadFromFile('.\Debugmap.bmp');
  end;
  LTarget := TBitmap.Create(1024, 1024);
  try
    LTarget.PixelFormat := pf32bit;
    LRender := TMundusRenderer.Create();
    try
      LRender.SetResolution(LTarget.Width, LTarget.Height);
      LBuffers := LRender.NewFrame;
      for LMesh in LScene.Meshes do
      begin
        if Assigned(LMesh.Vertices) then
        begin
          LQuery.AddMesh(LMesh);
          SetLength(LIndices, Length(LMesh.Triangles) * 3);
          for i := 0 to Pred(Length(LMesh.Triangles)) do
          begin
            LIndices[i * 3] := LMesh.Triangles[i].VertexA;
            LIndices[i * 3 + 1] := LMesh.Triangles[i].VertexB;
            LIndices[i * 3 + 2] := LMesh.Triangles[i].VertexC;
          end;
          LBuffer := LBuffers.Add();
          LBuffer.BindIndexedVertices(LMesh.Vertices, LIndices);
          LBuffer.BindShader(LShader);
          LBuffer.UniformValues.Bind('Query', LQuery);
          LBuffer.UniformValues.Bind<TFloat3>('Light', LLight);
          LBuffer.UniformValues.Bind('DebugMap', LDebugMap);
          LBuffer.Values.BindArray<TFloat2>('UV', LMesh.UVs[1]);
          LBuffer.Values.BindArray<TFloat3>('Normal', LMesh.Normals);
        end;
      end;
      LRender.RenderFrame(LTarget.Canvas);
      LRender.NewFrame;
      LRender.RenderFrame(LTarget.Canvas);
      LTarget.Canvas.CopyRect(LTarget.Canvas.ClipRect, LTarget.Canvas, Rect(LTarget.Width, 0, 0, LTarget.Height));
    finally
      LRender.Free;
    end;
    LTarget.SaveToFile('Lightmap.bmp');
  finally
    LTarget.Free;
    LScene.Free;
    LQuery.Free;
  end;
end;

begin
  try
    Main;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
