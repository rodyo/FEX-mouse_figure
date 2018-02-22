% remove_callback  Non-destructively remove callback from graphics object
%
% The opposite of ADD_CALLBACK.
%
% EXAMPLE: 
%
% >> h = figure('WindowButtonDownFcn', @(h,e) myFcn1);
% >> add_callback(h, @(h,e) myFcn2, 'WindowButtonDownFcn', 'first');
% >> remove_callback(h, @(h,e) myFcn2, 'WindowButtonDownFcn');
% 
%
% See also add_callback.
function remove_callback(hdl,...
                         removal_fcn,...
                         callbackname)
%{
Author: Rody Oldenhuis
        oldenhuis@gmail.com
%}
    % NOTE: (Rody Oldenhuis) R2011b introduced different argcheck mechanism
    % The following is the only way to handle ALL related warnings in ALL 
    % versions of MATLAB 
    if verLessThan('MATLAB', '7.13')
        error(   nargchk(2,3,nargin ,'struct')); %#ok<*NCHKN>
        error(nargoutchk(0,0,nargout,'struct')); %#ok<*NCHKE>       
    else
        narginchk(2,3);
        nargoutchk(0,0);   
    end
    
    assert(ishandle(hdl) && ishghandle(hdl) && isvalid(hdl),...
           [mfilename ':invalid_handle'],...
           'Argument HDL must be a handle to a valid graphics object.');
    
    assert(isa(removal_fcn, 'function_handle'),...
           [mfilename ':invalid_fcnhandle'],...
           'Callback function to remove must be given as a function handle.');
           
    % Process subsequent arguments
    if nargin>2
        assert(ischar(callbackname),...
               [mfilename ':arg_error'],...
               'Expected string for argument CALLBACKNAME; got "%s".',...
               class(callbackname));
    else
        % Set default values
        callbackname = 'Callback';        
    end
  
    % Assign new callback -------------------------------------------------
    
    current_callbacks = get(hdl, callbackname);
    
    % Easy cases: 
    % - no callback functions have been assigned.
    % - current function equals removal candidate
    if isempty(current_callbacks) || isequal(current_callbacks, removal_fcn)
        set(hdl, callbackname, []); return; end 
    
    % Otherwise, more care has to be taken 
    finfo = functions(current_callbacks);  
    % TODO: (Rody Oldenhuis) hardcoded function name
    if any(strcmp(finfo.file, {which('add_callback'); mfilename}))
        
        % TODO: (Rody Oldenhuis) hardcoded variable name        
        current_callbacks = finfo.workspace{1}.callbackstack;
        
        % Find those that need removing
        removals = cellfun(@isequal, removal_fcn, current_callbacks);
        if any(removals)   
            
            % Remove matching functions
            callbackstack = current_callbacks(~removals);
            
            % Assign a cellfun wrapper as the new callback        
            if isempty(callbackstack)
                set(hdl, callbackname, []); 
            else
                set(hdl, ...
                    callbackname, @(h,e) cellfun(@(x)x(h,e), callbackstack));
            end
        end
        
    else
        warning([mfilename ':unsupported_callback_function'], [...
                '%s is unable to determine with absolute certainty whether ',...
                'the specified function to be removed is called by the  ',...
                'callback function; taking no action.'],...
                mfilename);
    end
    
end
