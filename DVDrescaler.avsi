function DVDdescale(clip c, int "start_w", int "end_w", string "kernel", float "b", float "c_val", int "target_w", int "target_h") {

    # 1. Define defaults for optional parameters
    s_w = default(start_w, 639)
    e_w = default(end_w, 641)
    knl = default(kernel, "bilinear")
    
    # Fallback to 720 if not specified
    t_w = default(target_w, 720)
    t_h = default(target_h, 480)
    
    # Bicubic parameters
    b_p = default(b, 1.0/3.0)
    c_p = default(c_val, 1.0/3.0)
    
    # 2. Initialize the base clip
    result = GetDeClip(c, s_w, knl, b_p, c_p, t_w, t_h)

    # 3. Loop through the remaining range and average
    for (w = s_w + 1, e_w) {
        current_descale = GetDeClip(c, w, knl, b_p, c_p, t_w, t_h)
        result = mt_average(result, current_descale, Y=3, U=3, V=3)
    }

    return result
}

# Internal helper function
function GetDeClip(clip c, int Width1, string knl, float b_p, float c_p, int t_w, int t_h) {
    
    # 1. Descale only the width to Width1. Height is strictly forced to 480.
    descaled = (knl == "bicubic")  ? c.DeBicubicResizeMT(Width1, 480, b=b_p, c=c_p) :
    \          (knl == "bilinear") ? c.DeBilinearResizeMT(Width1, 480) :
    \                                c.DeBilinearResizeMT(Width1, 480)
    
    # 2. Rotate 90 degrees. 
    rotated = descaled.TurnLeft()
    
    # 3. Double only the horizontal axis of the original clip via NNEDI.
    upscaled_rotated = rotated.nnedi3(field=0, dh=true, nsize=4, nns=4, qual=1, etype=1, pscrn=2) #nsize 4 is 8x4, best for this small res
    
    # 4. Rotate back to normal orientation. Current dimensions: (Width1 * 2) x 480.
    restored = upscaled_rotated.TurnRight()
    
    # 5. Fix NNEDI 0.5-pixel horizontal field shift and map to target width.
    return restored.Spline64Resize(t_w, 480, src_left=-0.5, src_top=0, src_width=restored.Width(), src_height=480) #adjust field order "shift"
}	
