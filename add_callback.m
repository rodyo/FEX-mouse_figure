% add_callback   Non-destructively add callback function to graphics object
%
% Normally, when directly assigning a callback function to a graphics
% object, all its previously assigned callback functions are overwritten.
% This function adds the new callback without overwriting any previously
% assigned callbacks, preserving the current callback stack. 
%
% ADD_CALLBACK(H, NEWFCN) adds the new callback NEWFCN to a graphics object 
% with handle H. Here, NEWFCN is a function handle to the new callback 
% function. 
%
% ADD_CALLBACK(H, NEWFCN, CALLBACKNAME) adds the new callback to the
% handle's attribute with name CALLBACKNAME. By default, this equals 
% 'CallBack'. 
%
% ADD_CALLBACK(..., LOCATION) adds the new callback in the callstack at the
% specified LOCATION, where LOCATION equals 'first' or 'last' (default). 
%
% EXAMPLE: 
%
% >> h = figure('WindowButtonDownFcn', @(h,e) myFcn1);
% >> add_callback(h, @(h,e) myFcn2, 'WindowButtonDownFcn', 'first');
% 
%
% See also remove_callback.
function add_callback(hdl,...
                      new_fcn,...
                      callbackname,...
                      location)
%{
Author: Rody Oldenhuis
        oldenhuis@gmail.com
%}
    % Argument checking ---------------------------------------------------
        
    % NOTE: (Rody Oldenhuis) R2011b introduced different argcheck mechanism
    % The following is the only way to handle ALL related warnings in ALL 
    % versions of MATLAB 
    if verLessThan('MATLAB', '7.13')
        error(   nargchk(2,4,nargin ,'struct')); %#ok<NCHKN>
        error(nargoutchk(0,0,nargout,'struct')); %#ok<NCHKE>       
    else
        narginchk(2,4);
        nargoutchk(0,0);   
    end
    
    assert(ishandle(hdl) && ishghandle(hdl) && isvalid(hdl),...
           [mfilename ':invalid_handle'],...
           'Argument HDL must be a handle to a valid graphics object.');
    
    assert(isa(new_fcn, 'function_handle'),...
           [mfilename ':invalid_fcnhandle'],...
           'New callback function must be given as a function handle.');
       
    % Default values
	callbackname_dft = 'Callback';
    location_dft     = 'last';
       
    % Process subsequent arguments
    if nargin>2
        
        % Resolve argument ambiguity for 3 input arguments
        if nargin==3
            
            lastarg = callbackname;
            
            assert(ischar(lastarg),...
                   [mfilename ':arg_error'],...
                   'Last argument must be a string; got "%s".',...
                   class(lastarg));
            
            switch lower(lastarg)
                case {'last' 'first'}
                    location     = lastarg;
                    callbackname = callbackname_dft;
                otherwise
                    location     = location_dft;
                    callbackname = lastarg;                          
            end
            
        % Check if they are valid strings
        else        
            assert(ischar(callbackname),...
                   [mfilename ':arg_error'],...
                   'Expected string for argument CALLBACKNAME; got "%s".',...
                   class(callbackname));

            assert(ischar(location),...
                   [mfilename ':arg_error'],...
                   'Expected string for argument LOCATION; got "%s".',...
                   class(location));
              
            assert(any(strcmpi(location, {'last' 'first'})),...
                  [mfilename ':arg_error'], [...
                  'Unsupported value for argument LOCATION: "%s". ',...
                  'Supported values are "first" and "last".'],...
                  location);
        end       
    else
        % Set default values
        callbackname = callbackname_dft;
        location     = location_dft;
    end
  
    % Assign new callback ------------------------------------------------
    
    current_callbacks = get(hdl, callbackname);
    
    % When none have been set so far, insert it directly
    if isempty(current_callbacks)
        set(hdl, callbackname, new_fcn);
        
    % Otherwise, add it with a cellfun wrapper
    else
        % Initialize
        if ~iscell(current_callbacks)
            current_callbacks = {current_callbacks}; end
                        
        % Insert at the location indicated        
        switch lower(location)
            case 'last' , callbackstack = [current_callbacks(:); {new_fcn}]; 
            case 'first', callbackstack = [{new_fcn}; current_callbacks(:)];
        end
            
        % Now assign a cellfun wrapper as the new callback        
        set(hdl, ...
            callbackname, @(h,e) cellfun(@(x)x(h,e), callbackstack));
        
    end    
    
end
