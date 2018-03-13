clear; clc; 
figure(2); clf;
addpath('helpers');

%% A barebones example of how to use the iPALM code
% Generate some synthetic data, activation map values are {0,1}.
gen_synth_data;         
eta = 5e-2;         % Add some noise
b0 = 1*rand;       % Add a random constant bias
Y = Y + b0 + eta * randn(size(Y));

% Initialize an iPALM iterator for the SBD problem. 
p = size(A0{1});    % Choose a recovery window size
K = numel(A0);      % Choose # of atoms to recover
lambda1 = 0.1;      % Sparsity regularization parameter

xpos = true;        % Recover a nonnegative activation map
getbias = true;     % Recover a constant bias

[solver, synthesize] = mkcdl(Y, p, K, lambda1, true, true);     

%% Run some iterations of iPALM
reweights = 5;                          % number of reweights
lambda2 = 1e-2;                         % lambda for reweighting
eps = 1e-2;                             % reweighting param

maxit = 1e2 * ones(reweights+1,1);      % iterations per reweighting loop
maxit(1) = 2e3;                         % iterations in initial iPALM solve

centerfq = 5e2;                         % frequency to recenter the data
updates = [ 1 10:10:50 ...              % when to print updates
            100:100:500 ...
            600:200:max(maxit)];

solvers = cell(reweights+1,1);
costs = cell(reweights+1,1);  
stime = tic;  %profile on;
figure(1);  subplot(3,2,[1 3]);  imagesc(abs(Y-b0));
for r = 1:reweights+1
    if r > 1
        solver = reweight(solver, lambda2, eps);
    else
        figure(2); clf;
    end
    costs{r} = NaN(maxit(r),1);
    
    for i = 1:maxit(r)
        solver = iterate(solver);
        costs{r}(i) = solver.cost;

        if centerfq > 0 && mod(i, centerfq) == 0
            for k = 1:K
                [A, X, ~, A_, X_] = center(...
                    solver.A{k}, solver.X{k}, [],...
                    solver.A_{k}, solver.X_{k});
                solver.A{k} = A;  solver.X{k} = X;
                solver.A_{k} = A;  solver.X_{k} = X;
            end
        end
        
        if ismember(i, updates)
            tmp = ['Iteration ' num2str(solver.it)];
            
            figure(1);
            subplot(3,2,[2 4]); 
                imagesc(abs(synthesize(solver.A, solver.X, {0})));
            subplot(313); 
            for k = 1:r
                c = costs{k};
                if k == 1;  c = c(50:end);  end
                plot(linspace(0,1,numel(c)), c-min(c));  hold on;
            end
            hold off; title(tmp); drawnow;
            
            figure(2);
            for k = 1:K
                subplot(2,2*K,2*K*(r>1) + 2*k-1); 
                imagesc(abs(solver.A{k}));
                subplot(2,2*K,2*K*(r>1) + 2*k);
                imagesc(solver.X{k});
            end
            subplot(2,2*K,2*K*(r>1)+1); title(tmp);
            drawnow;
            
            fprintf(['Iter. %d:%d.  '...
                'Cost %.4e. Elapsed time %.2fs.\n'], ...
                r-1, solver.it, solver.cost, toc(stime));
        end
    end
    disp(' ');
    solvers{r} = copy(solver);
end
%profile off; profile viewer;