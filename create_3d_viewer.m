function h = create_3d_viewer(h)

% Reusability info:
% --------------------
% PLATFORM    : at least Windows. Untested on others.
% MIN. MATLAB : at least R2014b and up
% CODEGEN     : no
% DEPENDENCIES: none.
    
    h_axs = h.CurrentAxes;
    
    % Make sure the axes aren't clipping on us
    h_axs.Clipping = 'off';
    
    % Remove items from standard figure toolbar
    toolbar  = findall(h, 'Type', 'uitoolbar');
    items    = allchild(toolbar);
    removals = ismember(get(items,'Tag'), {...
                        'Exploration.Rotate'
                        'Exploration.ZoomIn';
                        'Exploration.ZoomOut'
                        'Exploration.Pan'});
    delete(items(removals));
    
    % Set default view    
    camproj perspective
    axis equal vis3d
          
    UD.default_view_settings = {'View'               , h_axs.View,...
                                'CameraPosition'     , h_axs.CameraPosition,...
                                'CameraPositionMode' , h_axs.CameraPositionMode,...
                                'CameraTarget'       , h_axs.CameraTarget,...
                                'CameraTargetMode'   , h_axs.CameraTargetMode,...
                                'CameraViewAngle'    , h_axs.CameraViewAngle,...
                                'CameraViewAngleMode', h_axs.CameraViewAngleMode,...
                                'XLim'               , h_axs.XLim,...
                                'YLim'               , h_axs.YLim,...
                                'ZLim'               , h_axs.ZLim};
    h_axs.UserData = UD;
    
    % Show help text
    
    menu_up = true;
    
    text_height = 85; % pixels
    btn_size    = 20;
    btn_offset  = 25;
    
    function p = get_size_in_pixels(q)
        prev_units = q.Units;
        q.Units = 'Pixels';
        p = q.Position;
        q.Units = prev_units;
    end
    
    p   = get_size_in_pixels(h);    
    txt = uicontrol('parent'  , h,...
                    'style'   , 'text',...
                    'units'   , 'normalized',...
                    'position', [0.0 0.0 1.0 text_height/p(4)],...              
                    'FontName', 'FixedWidth',...
                    'FontSize', 8,...
                    'HorizontalAlignment', 'left',...
                    'String',  sprintf(['scroll/ctrl+up/down arrow keys: zoom\n',...
                                        'left-click drag               : rotate\n',...
                                        'right-click drag/arrow keys   : pan\n',...
                                        'ctrl+drag                     : roll\n',...    
                                        'double-click                  : reset center\n',...                                  
                                        'middle-click                  : reset to initial view']));
                                    
    btn = uicontrol('parent'  , h,...
                    'style'   , 'pushbutton',...
                    'units'   , 'normalized',...
                    'position', [1.0-btn_offset/p(3),...
                                 (text_height-btn_size)/p(4),...
                                 btn_size/p(3),...
                                 btn_size/p(4)],...
                    'string'  , char(8595),...
                    'callback', @hide_help);
                
    function hide_help(~,~)
        p = get_size_in_pixels(h); 
        q = btn.Position;
        if menu_up
            menu_up = false;
            txt.Visible = 'off';
            set(btn, ...
                'String'  , char(8593),...
                'position', [q(1),...
                             (btn_offset-btn_size)/p(4),...
                             q(3:4)]);
        else
            menu_up = true;
            txt.Visible = 'on';
            set(btn, ...
                'String'  , char(8595),...
                'position', [q(1),...
                             (text_height-btn_size)/p(4),...
                             q(3:4)]);
        end
    end
                                    
    h.ResizeFcn = @resize_figure;    
    function resize_figure(~,~)        
        p = get_size_in_pixels(h);
        txt.Position = [0.0 0.0 1.0 text_height/p(end)];
        btn.Position = [1.0 - btn_offset/p(3), 0, btn_size./p(3:4)];
        if menu_up
            btn.Position(2) = (text_height-btn_size)/p(4);                           
        else
            btn.Position(2) = (btn_offset-btn_size)/p(4);                           
        end
    end
    
    % Now define all the plot manipulation tools
    add_callback(h, @key_press,     'WindowKeyPressFcn'    );
    add_callback(h, @key_release,   'WindowKeyReleaseFcn'  );
    add_callback(h, @mouse_scroll,  'WindowScrollWheelFcn' );
    add_callback(h, @mouse_click,   'WindowButtonDownFcn'  );
    add_callback(h, @mouse_release, 'WindowButtonUpFcn'    );
    add_callback(h, @mouse_move,    'WindowButtonMotionFcn');  
            
    % NOTE (Rody Oldenhuis): the callbacks below manipulate these 
    % "locally global" variables.
    zoom_start = 0;
    zoom_timer = [];
    
    keypressed = [];
    
    clicked = struct('left'  , false,...
                     'right' , false,...
                     'middle', false,...
                     'click_position_left'  , NaN(1,2),...
                     'click_position_right' , NaN(1,2),...
                     'click_position_middle', NaN(1,2));
                 
    % Functionality ------------------------------------------------------------
    
    % What happens when pressing a keyboard key?    
    function key_press(~, eventData)

        if ~isequal(eventData, keypressed)
            keypressed = eventData;
        else
            return;
        end
        
        firstpass = true;        
        while ~isempty(keypressed)
        
            % Process all registered keyboard accelerators 
            modkey = eventData.Modifier;
            
            % (without any modifiers)  
            if isempty(modkey) 

                pos = get_point();
                execute_pan = false;
                
                % Panning
                switch eventData.Key
                    case 'leftarrow' , execute_pan=true; pos(1) = pos(1) + 15;
                    case 'rightarrow', execute_pan=true; pos(1) = pos(1) - 15;
                    case 'uparrow'   , execute_pan=true; pos(2) = pos(2) - 15;
                    case 'downarrow' , execute_pan=true; pos(2) = pos(2) + 15;
                end  
                
                if execute_pan                    
                    do_pan(pos); end
                                
            % (with modifiers)  
            else            
                % Control
                if all(strcmpi(modkey, 'control'))

                    % Zooming 
                    zoomfactor = [];
                    switch eventData.Key
                        case 'uparrow'   , zoomfactor = 1 + 0.08;
                        case 'downarrow' , zoomfactor = 1 - 0.08;
                    end

                    if ~isempty(zoomfactor)
                        do_zoom(zoomfactor); end
                end

            end
            
            % IMPORTANT! key repetitions without getting stuck in the loop
            if firstpass
                pause(0.3);
                firstpass = false;
            else
                pause(0.02);
            end
            
        end

    end
    
    % What happens when releasing a keyboard key?
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
    function mouse_click(fig,~)

        fn = get_mousebtn_type(fig);

        switch lower(fn)
            
            case 'double'                
                 % Double click: restore default camera target
                 % NOTE: (Rody Oldenhuis) HARD-CODED INDEX; beware!
                 h_axs.CameraTarget = h_axs.UserData.default_view_settings{8};
                 
            case 'middle'                
                % Middle click: restore view settings                
                set(h_axs, h_axs.UserData.default_view_settings{:});
                 
            otherwise                                
                if ~clicked.(fn)
                    clicked.(['click_position_' fn]) = h.CurrentPoint; end                
                clicked.(fn) = true;                
        end

    end
    
    % What happens when releasing a mouse button?
    function mouse_release(fig, ~)

        fn = get_mousebtn_type(fig);

        if ~strcmp(fn, 'double')
            clicked.(fn) = false;
            clicked.(['click_position_' fn]) = NaN(1,2);
        end
                
        % Reset mouse cursor
        h.Pointer = 'arrow';

    end

    % What happens when moving the mouse?
    function mouse_move(~,~)

        persistent prev_pos 
        
        % Rotating
        if clicked.left 

            % Use camorbit to move the camera around the scene. Note that this 
            % is different from rotate3d, which adjusts az/el and does awkward 
            % things when reaching the poles of the spherical coordinate system

            % Get position and current view
            if isempty(prev_pos)
                prev_pos = get_point(); end

            new_pos = get_point();

            delta_az = 0.6*(prev_pos(1) - new_pos(1));                    
            delta_el = 0.6*(prev_pos(2) - new_pos(2)); 

            camorbit(delta_az, delta_el, 'camera');
            prev_pos = new_pos;

        % Panning / rolling
        elseif clicked.right   
            
            % Control-click: roll
            if ~isempty(keypressed) && all(strcmpi(keypressed.Modifier, 'control'))
                prev_pos = do_roll(prev_pos);
             
            % Open click: pan
            else
                prev_pos = do_pan(prev_pos);
            end

        else
            h.Pointer = 'arrow';
            prev_pos = [];            
        end
        
    end
    
    % Panning
    function new_pos = do_pan(prev_pos)
        
        % Get position
        if isempty(prev_pos)
            prev_pos = get_point(); end
        
        % Get original camera parameters
        ct  = h_axs.CameraTarget;
        cp  = h_axs.CameraPosition;
        up  = h_axs.CameraUpVector;
        dar = h_axs.DataAspectRatio;
        cva = h_axs.CameraViewAngle;
        axp = getpixelposition(h_axs);
        
        % Get desired shift in coordinates
        new_pos = get_point();
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
            h_axs.CameraPosition = newcp; end
        
        if all(isfinite(newct))
            h_axs.CameraTarget = newct; end
    end
    
    % Zooming
    function do_zoom(zoomfactor)
        
        zoom_start = tic();

        % Carry out camera-move zooming
        % NOTE: this is different from camzoom, which just adjusts the
        % camera angle. The zoom below allows you to go "inside" the spacecraft
        
        % Set mouse cursor
        if zoomfactor > 1
            setptr(h, 'glassplus');
        elseif zoomfactor < 1
            setptr(h, 'glassminus');
        end
        
        % Zoom target depends on current mouse position
        T = h_axs.CameraTarget;
       %C = h_axs.CameraPosition;
        P = h_axs.CurrentPoint;
        Q = mean(P);
        
        % Most natural-feeling 3D zoom:
        % 1. zoom in on zoom target
        % 2. shift camera target towards zoom target by the same amount
        h_axs.CameraTarget = Q;
        
        Z = zoomfactor - 1;        
        camdolly(h_axs, 0,0,Z, 'FixTarget', 'Camera');
        h_axs.CameraTarget = T + Z*(Q-T);  
        
        % adjust axes limits
        %axis([-5 +5 -10 +10 -4 +4])
        % TODO
        
        % Reset mouse cursor
        if isempty(zoom_timer)
            zoom_timer = timer('TimerFcn', @reset_cursor,...
                               'StopFcn' , @remove_timer);
            start(zoom_timer);
        end
        
        function reset_cursor(~,~)
            while true
                if toc(zoom_start) > 0.5
                    h.Pointer = 'arrow';
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
    
    % Rolling
    function new_pos = do_roll(prev_pos)
        
        % Get position
        if isempty(prev_pos)
            prev_pos = get_point(); end        
        new_pos = get_point();
        
        % Find figure center
        P = abs(h.Position);
        C = P(3:4)/2;
         
        % Compute dtheta
        old_P  = prev_pos - C;
        old_th = atan2(old_P(2), old_P(1));
        
        new_P  = new_pos - C;
        new_th = atan2(new_P(2), new_P(1));
        
        % Carry out roll        
        camroll(h_axs, 180/pi*(new_th - old_th));
        
    end
    
    % Helpers ------------------------------------------------------------------
    
    % Get current point in pixels
    function current_position = get_point()
        prev_units = h.Units;
        h.Units = 'pixels';
        current_position = h.CurrentPoint;
        h.Units = prev_units;
    end
    
    % Get the intuitive strings for mouse-click actions, as well as
    % some initialiations
    function fn = get_mousebtn_type(fig)
        
        switch fig.SelectionType
            
            % left click:  initiate 3d rotate
            case 'normal'
                fn = 'left';
                setptr(h, 'rotate');
                
            % right click: initiate panning
            case 'alt'
                fn = 'right';
                setptr(h, 'closedhand');
                
            % middle click
            case 'extend', fn = 'middle';
                
            % double click
            case 'open', fn = 'double';
                
        end
        
    end
    
end
