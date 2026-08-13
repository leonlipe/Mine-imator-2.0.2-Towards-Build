/// catmullrom_interpolate(p0, p1, p2, p3, t)
/// @arg p0
/// @arg p1
/// @arg p2
/// @arg p3
/// @arg t
/// @desc Returns a value on a uniform Catmull-Rom spline between p1 and p2 at t (0-1),
///       using p0 and p3 as the neighboring control values. Ported from Blockbench/three.js.

function catmullrom_interpolate(p0, p1, p2, p3, t)
{
	var v0, v1, t2, t3;
	v0 = (p2 - p0) * 0.5
	v1 = (p3 - p1) * 0.5
	t2 = t * t
	t3 = t * t2

	return (2 * p1 - 2 * p2 + v0 + v1) * t3 + (-3 * p1 + 3 * p2 - 2 * v0 - v1) * t2 + v0 * t + p1
}
