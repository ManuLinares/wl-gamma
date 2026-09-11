module wl_gamma;
import std::math;

alias Vec3d = double[<3>];

const ushort DEFAULT_TEMP       = 6500;
const ushort MIN_TEMP           = 1000;
const ushort MAX_TEMP           = 10000;
const double DEFAULT_GAMMA      = 1.0;
const double MIN_GAMMA          = 0.1;
const double DEFAULT_BRIGHTNESS = 1.0;
const double MIN_BRIGHTNESS     = 0.0;
const double MAX_BRIGHTNESS     = 1.0;

const Vec3d[*] BLACKBODY_COLOR = {
	{ 1.00000000, 0.18172716, 0.00000000 },
	{ 1.00000000, 0.25503671, 0.00000000 },
	{ 1.00000000, 0.30942099, 0.00000000 },
	{ 1.00000000, 0.35357379, 0.00000000 },
	{ 1.00000000, 0.39091524, 0.00000000 },
	{ 1.00000000, 0.42322816, 0.00000000 },
	{ 1.00000000, 0.45159884, 0.00000000 },
	{ 1.00000000, 0.47675916, 0.00000000 },
	{ 1.00000000, 0.49923747, 0.00000000 },
	{ 1.00000000, 0.51943421, 0.00000000 },
	{ 1.00000000, 0.54360078, 0.08679949 },
	{ 1.00000000, 0.56618736, 0.14065513 },
	{ 1.00000000, 0.58734976, 0.18362641 },
	{ 1.00000000, 0.60724493, 0.22137978 },
	{ 1.00000000, 0.62600248, 0.25591950 },
	{ 1.00000000, 0.64373109, 0.28819679 },
	{ 1.00000000, 0.66052319, 0.31873863 },
	{ 1.00000000, 0.67645822, 0.34786758 },
	{ 1.00000000, 0.69160518, 0.37579588 },
	{ 1.00000000, 0.70602449, 0.40267128 },
	{ 1.00000000, 0.71976951, 0.42860152 },
	{ 1.00000000, 0.73288760, 0.45366838 },
	{ 1.00000000, 0.74542112, 0.47793608 },
	{ 1.00000000, 0.75740814, 0.50145662 },
	{ 1.00000000, 0.76888303, 0.52427322 },
	{ 1.00000000, 0.77987699, 0.54642268 },
	{ 1.00000000, 0.79041843, 0.56793692 },
	{ 1.00000000, 0.80053332, 0.58884417 },
	{ 1.00000000, 0.81024551, 0.60916971 },
	{ 1.00000000, 0.81957693, 0.62893653 },
	{ 1.00000000, 0.82854786, 0.64816570 },
	{ 1.00000000, 0.83717703, 0.66687674 },
	{ 1.00000000, 0.84548188, 0.68508786 },
	{ 1.00000000, 0.85347859, 0.70281616 },
	{ 1.00000000, 0.86118227, 0.72007777 },
	{ 1.00000000, 0.86860704, 0.73688797 },
	{ 1.00000000, 0.87576611, 0.75326132 },
	{ 1.00000000, 0.88267187, 0.76921169 },
	{ 1.00000000, 0.88933596, 0.78475236 },
	{ 1.00000000, 0.89576933, 0.79989606 },
	{ 1.00000000, 0.90198230, 0.81465502 },
	{ 1.00000000, 0.90963069, 0.82838210 },
	{ 1.00000000, 0.91710889, 0.84190889 },
	{ 1.00000000, 0.92441842, 0.85523742 },
	{ 1.00000000, 0.93156127, 0.86836903 },
	{ 1.00000000, 0.93853986, 0.88130458 },
	{ 1.00000000, 0.94535695, 0.89404470 },
	{ 1.00000000, 0.95201559, 0.90658983 },
	{ 1.00000000, 0.95851906, 0.91894041 },
	{ 1.00000000, 0.96487079, 0.93109690 },
	{ 1.00000000, 0.97107439, 0.94305985 },
	{ 1.00000000, 0.97713351, 0.95482993 },
	{ 1.00000000, 0.98305189, 0.96640795 },
	{ 1.00000000, 0.98883326, 0.97779486 },
	{ 1.00000000, 0.99448139, 0.98899179 },
	{ 1.00000000, 1.00000000, 1.00000000 },
	{ 0.98947904, 0.99348723, 1.00000000 },
	{ 0.97940448, 0.98722715, 1.00000000 },
	{ 0.96975025, 0.98120637, 1.00000000 },
	{ 0.96049223, 0.97541240, 1.00000000 },
	{ 0.95160805, 0.96983355, 1.00000000 },
	{ 0.94303638, 0.96443333, 1.00000000 },
	{ 0.93480451, 0.95923080, 1.00000000 },
	{ 0.92689056, 0.95421394, 1.00000000 },
	{ 0.91927697, 0.94937330, 1.00000000 },
	{ 0.91194747, 0.94470005, 1.00000000 },
	{ 0.90488690, 0.94018594, 1.00000000 },
	{ 0.89808115, 0.93582323, 1.00000000 },
	{ 0.89151710, 0.93160469, 1.00000000 },
	{ 0.88518247, 0.92752354, 1.00000000 },
	{ 0.87906581, 0.92357340, 1.00000000 },
	{ 0.87315640, 0.91974827, 1.00000000 },
	{ 0.86744421, 0.91604254, 1.00000000 },
	{ 0.86191983, 0.91245088, 1.00000000 },
	{ 0.85657444, 0.90896831, 1.00000000 },
	{ 0.85139976, 0.90559011, 1.00000000 },
	{ 0.84638799, 0.90231183, 1.00000000 },
	{ 0.84153180, 0.89912926, 1.00000000 },
	{ 0.83682430, 0.89603843, 1.00000000 },
	{ 0.83225897, 0.89303558, 1.00000000 },
	{ 0.82782969, 0.89011714, 1.00000000 },
	{ 0.82353066, 0.88727974, 1.00000000 },
	{ 0.81935641, 0.88452017, 1.00000000 },
	{ 0.81530175, 0.88183541, 1.00000000 },
	{ 0.81136180, 0.87922257, 1.00000000 },
	{ 0.80753191, 0.87667891, 1.00000000 },
	{ 0.80380769, 0.87420182, 1.00000000 },
	{ 0.80018497, 0.87178882, 1.00000000 },
	{ 0.79665980, 0.86943756, 1.00000000 },
	{ 0.79322843, 0.86714579, 1.00000000 },
	{ 0.78988728, 0.86491137, 1.00000000 },
	{ 0.78663296, 0.86273225, 1.00000000 }
};

struct Color
{
	ushort temp;
	double gamma;
	double brightness;
	bool inverted;
}

fn Color color_default()
{
	return {
		.temp = DEFAULT_TEMP,
		.gamma = DEFAULT_GAMMA,
		.brightness = DEFAULT_BRIGHTNESS,
		.inverted = false
	};
}

fn bool Color.set_temp(Color* self, ushort temp)
{
	ushort clamped = (ushort)math::clamp((int)temp, (int)MIN_TEMP, (int)MAX_TEMP);
	if (self.temp == clamped) return false;
	self.temp = clamped;
	return true;
}

fn bool Color.set_gamma(Color* self, double val)
{
	double clamped = val < MIN_GAMMA ? MIN_GAMMA : val;
	if (self.gamma == clamped) return false;
	self.gamma = clamped;
	return true;
}

fn bool Color.set_brightness(Color* self, double val)
{
	double clamped = math::clamp(val, MIN_BRIGHTNESS, MAX_BRIGHTNESS);
	if (self.brightness == clamped) return false;
	self.brightness = clamped;
	return true;
}

fn bool Color.update_temp(Color* self, short delta)
{
	ushort new_temp = (ushort)math::clamp(self.temp + delta, MIN_TEMP, MAX_TEMP);
	if (self.temp == new_temp)
	{
		return false;
	}
	self.temp = new_temp;
	return true;
}

fn bool Color.update_gamma(Color* self, double delta)
{
	double new_gamma = self.gamma + delta;
	if (new_gamma < MIN_GAMMA)
	{
		new_gamma = MIN_GAMMA;
	}
	if (self.gamma == new_gamma)
	{
		return false;
	}
	self.gamma = new_gamma;
	return true;
}

fn bool Color.update_brightness(Color* self, double delta)
{
	double new_brightness = math::clamp(self.brightness + delta, MIN_BRIGHTNESS, MAX_BRIGHTNESS);
	if (self.brightness == new_brightness)
	{
		return false;
	}
	self.brightness = new_brightness;
	return true;
}

fn ushort[<3>] map_rgb(double v, Vec3d white, Color color, double v_max_gamma)
{
	if (v <= 0.0)
	{
		return {};
	}

	Vec3d vw = v * white;
	Vec3d intensity = {
		math::pow(vw.x, color.gamma) * v_max_gamma,
		math::pow(vw.y, color.gamma) * v_max_gamma,
		math::pow(vw.z, color.gamma) * v_max_gamma
	};
	Vec3d clamped = intensity.clamp((Vec3d)0.0, (Vec3d)ushort::max);

	return (ushort[<3>])clamped;
}

fn void colorramp_fill(ushort* r, ushort* g, ushort* b, sz ramp_size, Color color)
{
	if (ramp_size <= 1)
	{
		return;
	}

	if (color.brightness <= 0.0)
	{
		r[:ramp_size] = 0;
		g[:ramp_size] = 0;
		b[:ramp_size] = 0;
		return;
	}

	sz color_i = (sz)((color.temp - MIN_TEMP) / 100);
	if (color_i + 1 >= BLACKBODY_COLOR.len)
	{
		color_i = BLACKBODY_COLOR.len - 2;
	}
	double a = (double)(color.temp % 100) / 100.0;
	Vec3d white = BLACKBODY_COLOR[color_i].lerp(BLACKBODY_COLOR[color_i + 1], a);

	double v_max = ushort::max * color.brightness;
	double v_max_gamma = math::pow(v_max, 1.0 - color.gamma);
	double step = v_max / (double)(ramp_size - 1);

	for (sz i = 0; i < ramp_size; i++)
	{
		double v = step * (double)i;
		sz idx = color.inverted ? (ramp_size - 1 - i) : i;

		// Compute 3 channels simultaneously into a SIMD vector:
		ushort[<3>] rgb = map_rgb(v, white, color, v_max_gamma);

		// Store into planar buffers via swizzle accessors:
		r[idx] = rgb.r;
		g[idx] = rgb.g;
		b[idx] = rgb.b;
	}
}