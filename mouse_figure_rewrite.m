function mouse_figure_rewrite(hFig)
    
    % Initialize ----------------------------------------------------------
    
    % initialize axes
    if (nargin == 0) || ~ishandle(hFig)
        hFig  = figure;  
        hAxes = gca;
    else
        assert(ishghandle(hFig) && strcmp(get(hFig, 'type'), 'figure'),...
               [mfilename ':invalid_handle'],...
               [mfilename '() takes a figure handle as input argument.']);
        
        hAxes = get(hFig, 'CurrentAxes')
    end

    % Add all the callbacks to the GUI 
    add_callback(hFig, @key_press    , 'WindowKeyPressFcn'    );
    add_callback(hFig, @key_release  , 'WindowKeyReleaseFcn'  );
    add_callback(hFig, @mouse_scroll , 'WindowScrollWheelFcn' );
    add_callback(hFig, @mouse_click  , 'WindowButtonDownFcn'  );
    add_callback(hFig, @mouse_release, 'WindowButtonUpFcn'    );
    add_callback(hFig, @mouse_move   , 'WindowButtonMotionFcn');
    
    %{
    NOTE (Rody Oldenhuis):
    
    The callbacks below manipulate these "global" variables. This is a
    tiny bit faster than using class properties, but with these 
    callbacks, any increase in speed really matters. 
    
    It is also less messy, but that is more of an opinion :) 
    %}
    
    zoom_start = 0;  
    zoom_timer = [];

    keypressed = [];

    clicked = struct('left'  , false,...
                     'right' , false,...
                     'middle', false,...
                     'click_position_left'  , NaN(1,2),...
                     'click_position_right' , NaN(1,2),...
                     'click_position_middle', NaN(1,2));
                 
              
    % Functionality--------------------------------------------------------

    % What happens when pressing a key on the keyboard?
    % NOTE: (Rody Oldenhuis) "EventName" is not a field of the eventData in 
    % earlier versions of MATLAB, hence 2 callback functions
    function key_press(~, eventData)

        if ~isequal(eventData, keypressed)
            keypressed = eventData;
        else
            return;
        end
        
        % Process all registered keyboard accelerators 
        modkey = eventData.Modifier;
        
        % (without modifiers)  
        if isempty(modkey) 
            
            % Panning
            pos         = get_figparam_in_pixels('CurrentPoint');
            execute_pan = false;
            
            switch eventData.Key
                
                % Panning
                case 'leftarrow' , execute_pan=true; pos(1) = pos(1) - 15;
                case 'rightarrow', execute_pan=true; pos(1) = pos(1) + 15;
                    
                case 'uparrow'   , execute_pan=true; pos(2) = pos(2) + 15;
                case 'downarrow' , execute_pan=true; pos(2) = pos(2) - 15;
                    
            end 
            
            if execute_pan                    
                do_pan(pos); end
        
        % (with modifiers)  
        else            
            % Control/command            
            if all(strcmpi(modkey, 'control')) || all(strcmpi(modkey, 'command'))                
                
                zoomfactor = [];
                switch eventData.Key

                    % Zooming 
                    case 'uparrow'   , zoomfactor = 1 + 0.08;
                    case 'downarrow' , zoomfactor = 1 - 0.08;

                end

                if ~isempty(zoomfactor)
                    do_zoom(zoomfactor); end
                
                
            end
            
        end

    end
    
    function key_release(~,~)
        keypressed = [];
        return;
    end

    % What happens when scrolling the mouse wheel?
    function mouse_scroll(~, eventData)
                
        % Set appropriate zoom factor
        scrolls    = eventData.VerticalScrollCount; % >0: down scroll, <0: up scroll
        zoomfactor = 1 - scrolls*0.08;        
        zoomfactor = min(1.6,max(0.4, zoomfactor));
        
        % Carry out zoom
        do_zoom(zoomfactor);
        
    end
    
    % What happens when clicking the mouse?
    % NOTE: (Rody Oldenhuis) "EventName" is not a field of the eventData in 
    % earlier versions of MATLAB, hence 2 separate callback functions for  
    % mouse clicks
    function fn = get_mousebtn_type(fig)
        
        switch get(fig, 'SelectionType')
            case 'normal' % left click
                fn = 'left'; 

            case 'alt' % right click, or left click with a modifier                        
                % TODO: (Rody Oldenhuis) no, middle click with
                % modifier also gives 'alt'
                if ~isempty(keypressed) && ~isempty(keypressed.Modifier)
                    fn = 'left'; 
                else
                    fn = 'right'; 
                end

            case 'extend' % middle click
                fn = 'middle';  

            case 'open' % double click 
                fn = 'double';  
        end
        
    end
    
    function mouse_click(fig,~)

        fn = get_mousebtn_type(fig);        
        
        % non-double click
        if ~strcmp(fn, 'double')

            pos = get(hFig, 'CurrentPoint');
           
            if ~clicked.(fn)
                clicked.(['click_position_' fn]) = pos; end

            clicked.(fn) = true;
            
        % Double click
        else
            % Restore default zoom/rotation
            obj.restoreDefaultPlotView();
        end

    end
    
    function mouse_release(fig, ~)

        fn = get_mousebtn_type(fig);        

        % Perform cleanup actions on non-double-click release
        if ~strcmp(fn, 'double') 
            
            clicked.(fn) = false;
            clicked.(['click_position_' fn]) = NaN(1,2);
            
            % Reset mouse cursor and central coordinate indicator
            set(hFig, 'Pointer', 'arrow');            
        end

    end

    % Moving the mouse will: 
    % - pan as long as right button is pressed
    % - rotate as long as left button is pressed
    function mouse_move(~,~)

        persistent prev_pos oldAzEl

        % Rotate point cloud
        if clicked.left 

            % Set mouse cursor
            if isempty(prev_pos)                        
                setptr(hFig, 'rotate'); end
            
            % with Ctrl-Key/Command-key pressed down, use the 
            % regular version from rotate3d. Otherwise, use the 
            % camorbit one
            if ~isempty(keypressed) && ...
                    any(strcmp(keypressed.Key, {'control' 'command'}))

                % Get position and current view
                if isempty(prev_pos)
                    prev_pos = get_figparam_in_pixels('CurrentPoint');
                    oldAzEl  = get(hAxes, 'View');
                end

                new_pos = get_figparam_in_pixels('CurrentPoint');

                % Map a dx dy to an azimuth and elevation
                delta_az = 0.4*(prev_pos(1) - new_pos(1));                    
                delta_el = 0.4*(prev_pos(2) - new_pos(2)); 
                azel     = normalize_azel([oldAzEl(1) + delta_az
                                           oldAzEl(2) + 2*delta_el]);

                % Apply new azimuth/elevation
                set(hAxes, 'View', azel);

            else

                % Get position and current view
                if isempty(prev_pos)
                    prev_pos = get_figparam_in_pixels('CurrentPoint'); end

                new_pos = get_figparam_in_pixels('CurrentPoint');

                delta_az = 0.6*(prev_pos(1) - new_pos(1));                    
                delta_el = 0.6*(prev_pos(2) - new_pos(2)); 

                camorbit(delta_az, delta_el);
                prev_pos = new_pos;

            end

            % NOTE: (Rody Oldenhuis) MATLAB R2015a introduced useful 
            % additions to drawnow
            if verLessThan('matlab', '8.5')
                drawnow expose;
            else
                drawnow limitrate;
            end
            
        % Panning / rolling
        elseif clicked.right
            
            % Set mouse cursor
            if isempty(prev_pos)                        
                setptr(hFig, 'closedhand'); end
                        
            % Enable panning
            prev_pos = do_pan(prev_pos);            

        elseif isempty(zoom_timer)
            
            % Reset mouse cursor and central coordinate indicator
            set(hFig, 'Pointer', 'arrow');
            
            % Reset these for the next time round
            prev_pos = [];
            oldAzEl  = [];
        end
        

        % Map azel from -180 to 180.
        function azel = normalize_azel(azel)
            if abs(azel(2)) > 90     
                azel(1) = azel(1) + 180;
                azel(2) = sign(azel(2)) * (180-abs(azel(2)));
            end                    
            azel(1) = mod(azel(1), 360);
        end

    end
    

    % Functionality helpers -----------------------------------------------

    function V = get_hparam_in_pixels(h, param)
        prev_units = get(h, 'Units');
        set(h, 'Units', 'Pixels');                    
        V = get(h, param);                    
        set(h, 'Units', prev_units);                    
    end
    
    % Get current <figure property> in pixels
    function V = get_figparam_in_pixels(param)
        V = get_hparam_in_pixels(hFig, param);
    end
           
    % Execute a panning action based on a given position 
    function new_pos = do_pan(prev_pos)

        % Get position
        if isempty(prev_pos)
            prev_pos = get_figparam_in_pixels('CurrentPoint'); end

        % Get original camera parameters
        ct  = get(hAxes, 'CameraTarget'   );
        cp  = get(hAxes, 'CameraPosition' );
        up  = get(hAxes, 'CameraUpVector' );
        dar = get(hAxes, 'DataAspectRatio');            
        cva = get(hAxes, 'CameraViewAngle');
        axp = getpixelposition(hAxes);

        % Get desired shift in coordinates
        new_pos = get_figparam_in_pixels('CurrentPoint'); 
        dx = prev_pos(1) - new_pos(1);
        dy = prev_pos(2) - new_pos(2);
        
        % Setup up appropriate coordinate system
        normalize = @(x) x/norm(x);
        v = (ct-cp)./dar;
        distance = norm(v);
        r = normalize(cross(v, up./dar)); 
        u = normalize(cross(r, v));       

        % Take into account axes size and camera view angle
        fov   = 2*distance*tan(cva/2*pi/180);
        pix   = min(axp(3), axp(4));
        delta = fov/pix .* dar .* ((dx * r) + (dy * u));

        % New values 
        newcp = cp + delta;
        newct = ct + delta;

        % Apply them when they are valid
        if all(isfinite(newcp))                
            set(hAxes, 'CameraPosition', newcp); end

        if all(isfinite(newct))            
            set(hAxes, 'CameraTarget', newct); end
        
    end

    % Execute a zooming action
    function do_zoom(zoomfactor)
        
        zooming = (zoomfactor ~= 1);
        
        % Quick exit conditions
        if ~zooming 
            return; end
        
        zoom_start = tic();

        if zoomfactor > 1
            setptr(hFig, 'glassplus');
        elseif zoomfactor < 1
            setptr(hFig, 'glassminus');
        end

        % Zoom target depends on current mouse position
        T = get(hAxes, 'CameraTarget');        
        P = get(hAxes, 'CurrentPoint');
        Q = mean(P);
        
        % Most natural-feeling 3D zoom:
        % 1. zoom in on zoom target
        % 2. shift camera target towards zoom target by the same amount
        set(hAxes, 'CameraTarget', Q);
        
        Z = zoomfactor - 1;
        camdolly(hAxes, 0,0,Z, 'FixTarget', 'Camera');
        set(hAxes, 'CameraTarget', T + Z*(Q-T));        
        drawnow('expose');
        
        % When done zooming: reset mouse cursor 
        if isempty(zoom_timer)
            zoom_timer = timer('TimerFcn', @reset_cursor,...
                               'StopFcn' , @remove_timer);
            start(zoom_timer);
        end
        
        function reset_cursor(~,~)
            while true
                if toc(zoom_start) > 0.5
                    set(hFig, 'Pointer', 'arrow');                    
                    break;
                end
                pause(0.01);
            end            
        end        
        function remove_timer(~,~)
            delete(zoom_timer);
            zoom_timer = [];
        end
        
    end
    
end

