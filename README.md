[![View Mouse-friendly FIGURE on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/25666-mouse-friendly-figure)

[![Donate to Rody](https://i.stack.imgur.com/bneea.png)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=4M7RMVNMKAXXQ&source=url)

# FEX-mouse_figure

MOUSE_FIGURE(handle) creates a figure (or modifies an existing one with handle [handle]) that allows zooming with the scroll wheel and panning with mouse clicks, *without* first selecting the ZOOM or PAN tools from the toolbar. Moreover, zooming occurs to and from the point the mouse currently hovers over, instead of to and from the less intuitive "CameraPosition" as is the case with the default ZOOM. Naturally, the classical ZOOM and PAN toolbar icons are left unaltered.
Mouse button functionality:
Scroll: zoom in/out
Left click: pan
Double click: reset view to default view
Right click: set new default view
LIMITATIONS: This function (re-)efines several functions in the figure (WindowScrollWheelFcn, WindowButtonDownFcn, WindowButtonUpFcn and WindowButtonMotionFcn), so if you have any of these functions already defined they will get overwritten. Also, MOUSE_FIGURE() only works properly for 2-D plots. As such, it should only be used for simple, first-order plots intended for "quick-n-dirty" data exploration. Only tested on MATLAB 2009a, on WinXP platform.
EXAMPLE:

mouse_figure;
x = linspace(-1, 1, 10000);
y = sin(1./x);
plot(x, y)

If you love this work, please consider [a donation](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=4M7RMVNMKAXXQ&source=url).
