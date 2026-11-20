# Window world provenance

Four original panorama images were produced with built-in image generation on
November 19, 2026. Exact prompts and paths are in prompts.json. Their Gaussian
environments were reconstructed locally with Depth Anything V2 Small, then
converted to anisotropic surface Gaussians by Hearth20's preparation tool.
They are depth-inferred, not measured or multi-view-trained captures. Hidden
surfaces, metric depth accuracy and large translations remain limitations.

Depth Anything V2 Small: Apache-2.0. Source:
https://github.com/DepthAnything/Depth-Anything-V2
Model: https://huggingface.co/depth-anything/Depth-Anything-V2-Small
The handoff folder retains license, source/model revisions and checkpoint hash.
The model and PyTorch environment are offline authoring tools, not game assets.
Only the permissively licensed Small checkpoint was used.

Gaussian rendering uses GDGS 3.3 by ReconWorldLab, pinned to commit
c22024b33a24e06d8629c654825fabd0485b2dba:
https://github.com/ReconWorldLab/godot-gaussian-splatting
The MIT license is retained at addons/gdgs/LICENSE. Local changes: skip unused
compute imports, skip hidden sorting/light scans, optional Hearth20 arched-window
fragment clipping, and a material-configuration hook. Generic GDGS nodes retain
their unclipped behavior. The wrapper retains canonical Y-up coordinates.

The five-second Jax siren is an original procedural mono waveform. It respects
local Tavern & Party and Master volume/mute. No music service is integrated.
