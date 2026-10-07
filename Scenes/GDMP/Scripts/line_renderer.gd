extends Node

func line(pos1: Vector3, pos2: Vector3, color = Color.WHITE_SMOKE) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	
	mesh_instance = edit_line(mesh_instance, pos1, pos2, color)
	
	get_tree().get_root().add_child(mesh_instance)
	
	return mesh_instance

func edit_line(
	mesh_instance: MeshInstance3D,
	pos1: Vector3,
	pos2: Vector3,
	color = Color.WHITE_SMOKE
) -> MeshInstance3D:
	var direction: Vector3 = pos2 - pos1
	var length: float = direction.length()

	if length <= 0.001:
		return mesh_instance

	var cylinder: CylinderMesh = mesh_instance.mesh as CylinderMesh

	if cylinder == null:
		cylinder = CylinderMesh.new()
		cylinder.radial_segments = 8
		cylinder.rings = 1
		mesh_instance.mesh = cylinder
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	cylinder.top_radius = 0.4
	cylinder.bottom_radius = 0.4
	cylinder.height = length

	var material: StandardMaterial3D = mesh_instance.get_surface_override_material(0) as StandardMaterial3D

	if material == null:
		material = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_instance.set_surface_override_material(0, material)

	material.albedo_color = color

	var midpoint: Vector3 = (pos1 + pos2) / 2.0
	mesh_instance.global_position = midpoint

	var up: Vector3 = Vector3.UP
	var direction_normalized: Vector3 = direction.normalized()

	if abs(direction_normalized.dot(up)) > 0.999:
		up = Vector3.RIGHT

	mesh_instance.look_at(
		midpoint + direction_normalized,
		up
	)

	mesh_instance.rotate_object_local(Vector3.RIGHT, PI / 2.0)

	return mesh_instance
