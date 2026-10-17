# Renderer workspace

The first visual slice is a separate low-cost anime material and test scene.

Requirements: Mobile renderer support; optional albedo, normal and AO inputs; UV and triplanar modes; explicit safe texture-scale defaults; restrained toon/PBR hybrid; optional subtle rim lighting; expensive global illumination/reflection effects disabled by default. Include an isolated demo scene, and record shader compatibility and performance before changing PEAK materials.

The previous test showed texture_scale 1.0 kept a much denser world-projected texture than 0.1. Keep scale explicit; do not silently change tiling.
