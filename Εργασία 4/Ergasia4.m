hclc
clear
close all;
format long;

%% Parameters

e = 1e-4;
plotNum = 0;
gammaStrings = ["Constant Gamma","Optimized Gamma","Changing Gamma"];
dVecStrings = ["Levenberg Marquardt Method","Conjugate Gradient Method","Quasi Newton Method"];

% Inital Conditions
x_1 = [-0.5,0.5,-2,-3];
y_1 = [-0.5,0.5,-1, 3];
x_1 = [-2];
y_1 = [-1];

%% Gradient Descent
fprintf("####### GRADIENT DESCENT #######\n\n")


% 3 Different Methods of Calculating d_k Vector
for dVecMethod = 1 : 1
    
    fprintf("******* d_k Vector Calculation Method %d *******\n\n",dVecMethod)
    
% 3 Different Methods of Calculating Gamma
for gammaMethod = 1 : 3
    
    % Count Number of Plots
    plotNum = plotFunction(plotNum);
    fprintf("******* Gamma Method %d *******\n\n",gammaMethod)
    
    % For all Initial Conditions
    for i=1:length(x_1)
        
        fprintf("Initial Conditions [x,y] =  [%f,%f]\n",x_1(i),y_1(i));
        
        if gammaMethod == 1
            fprintf("Gamma is constant \n")
        elseif gammaMethod == 2
            fprintf("Gamma is optimized using Golden Section Method \n")
        else
            fprintf("Gamma is decaying through Iterations \n")
        end
        
        % Gradient Descent
        [x,y,k] = gradientDescent(x_1(i),y_1(i),e,gammaMethod,dVecMethod);
        
        fprintf("Min(f) = %f at [x,y] = [%f,%f] after %d repetitions\n\n", ...
            f(x(end),y(end)),x(end),y(end),k);
        
        % Plot Trace
        tracePlot (x,y,k,plotNum-1)
        tracePlot (x,y,k,plotNum)
    end
    
    figure(plotNum-1)
    title(['3D Plot - Gradient Descent Method - ',num2str(gammaStrings(gammaMethod)),' - ',num2str(dVecStrings(dVecMethod))])
    xlabel("x")
    ylabel("y")
    zlabel("f(x,y)")
    
    figure(plotNum)
    title(['2D Plot - Gradient Descent Method - ',num2str(gammaStrings(gammaMethod)),' - ',num2str(dVecStrings(dVecMethod))])
    xlabel("x")
    ylabel("y")
    zlabel("f(x,y)")
end
end

%% Save Plots

% for i = 1 : plotNum
%     figure(i)
%       if (mod(i,2)==1)
%          view(-5,-20)
%       end
%     savePlot([mfilename,'_',num2str(i)])
% end

%% Functions

% Plot given Function
function plotNum = plotFunction(plotNum)


x = linspace(-3.5, 3.5, 100);
y = linspace(-3.5, 3.5, 100);

[X,Y] = meshgrid(x,y);

func = [];
for i = 1:length(x)
    for j = 1:length(y)
        func(i,j) = f(X(i,j),Y(i,j));
    end
end

figure(plotNum+1)
surf(X,Y,func)
view(-10,25)
colorbar

figure(plotNum + 2)
contour(X,Y,func,20)
colorbar

plotNum = plotNum + 2;

end

function [x,y,k] = gradientDescent(x,y,e,gammaMethod,dVectorMethod)
k = 1;
d = [];
gamma = [];


while( norm( gradf(x(k),y(k)) ) >= e)
    
    if dVectorMethod == 1
        d(:,k) = levenbergMarquardt(x(k),y(k));
    elseif dVectorMethod == 2
        if k ~= 1 
            d(:,k) = conjGradients(x(k),y(k),x(k-1),y(k-1),d(:,k-1));
        else
            d(:,1) = - gradf(x(k),y(k));
        end
    else
        if k ~= 1
            [d(:,k),Delta_k] = quasiNewton(x(k),y(k),x(k-1),y(k-1),Delta_k);
        else
            Delta_k = 4*eye(2);
            d(:,1) = -Delta_k*gradf(x(k),y(k));
        end
    end
    
    gamma(k) = calcGamma(x(k),y(k),d(:,k),k,gammaMethod);
    x(k+1) = x(k) + gamma(k)*d(1,k);
    y(k+1) = y(k) + gamma(k)*d(2,k);
    
    k = k + 1;
end

end

function d_k = levenbergMarquardt(x_k,y_k)

    mu = abs(max(eig(hessianf(x_k,y_k))));
    step = 0.1;
    
    g = @ (mu) hessianf(x_k,y_k)+mu*eye(2) ;
    [~,isPositive] = chol(g(mu));
    
    % Change mu until g is Positive Definite
    while isPositive==1
        mu = mu + step ;
        [~,isPositive] = chol(g(mu));
    end
    
    % Solve linear system
    d_k = g(mu)\(-gradf(x_k,y_k));
end

function d_k = conjGradients(x_k,y_k,x_prev,y_prev,d_prev)

beta_k = gradf(x_k,y_k)'*( gradf(x_k,y_k)-gradf(x_prev,y_prev) )/(gradf(x_prev,y_prev)'*gradf(x_prev,y_prev));
d_k = -gradf(x_k,y_k) + beta_k*d_prev;

end

function [d_k,Delta_k] = quasiNewton(x_k,y_k,x_next,y_next,Delta_prev)
xi = 0.5;


q_k = gradf(x_next,y_next)-gradf(x_k,y_k);
p_k = [x_next-x_k;y_next-y_k];

t_k = q_k'*Delta_prev*q_k;
v_k = p_k/(p_k' * q_k) - Delta_prev*q_k/t_k;
Delta_k = Delta_prev + p_k*p_k'/(p_k' * q_k) - ...
    Delta_prev*q_k*q_k'*Delta_prev/(q_k'*Delta_prev*q_k) + xi*t_k*v_k*v_k';

d_k = -Delta_k*gradf(x_k,y_k);
end

function gamma = calcGamma(x_k, y_k, d_k, k, gammaMethod)

if gammaMethod == 1
    gamma = 0.5;
elseif gammaMethod == 2
    
    % function to be minimized with respect to gamma
    func = @(gamma) f(x_k+gamma*d_k(1) , y_k+gamma*d_k(2) );
    
    % Golden Section Parameters
    l = 1e-3;
    a = 1e-4;
    b = 2;
    
    % Minimization using Golden Section Method
    gamma = goldenSectionMethod(func,l,a,b);
    
else
    
    % Inital learning Rate
    gamma0 = 0.3;
    
    % Decay Parameter
    a = 0.004;
    
    % Time-Based Decay
     gamma = gamma0*exp(-a*k);
    
end

end

function minX = goldenSectionMethod(func,l,a,b)

gamma = (-1+sqrt(5))/2;
k = 1;
x1(k)=a(k)+(1-gamma)*(b(k)-a(k));
x2(k)=a(k)+gamma*(b(k)-a(k));

while b(k)-a(k)>=l
    
    if(func(x1(k))<=func(x2(k)))
        a(k+1)= a(k);
        b(k+1) = x2(k);
        x1(k+1) = a(k+1) + (1-gamma)*(b(k+1)-a(k+1));
        x2(k+1) = x1(k);
    else
        a(k+1) = x1(k);
        b(k+1)= b(k);
        x1(k+1) = x2(k);
        x2(k+1) = a(k+1) + gamma*(b(k+1)-a(k+1));
    end
    k = k + 1;
end

% Minimum point in the center of the final interval
minX = (a(end)+b(end))/2;

end

% Plot trace
function tracePlot (x,y,k,plotNum)

trace_f = [];

for i = 1:k
    trace_f(i) = f(x(i),y(i));
end

figure(plotNum)
hold on;
plot3(x,y,trace_f,"-r+",'linewidth',1)

% Plot minimum point
hold on;
plot3(x(end),y(end),f(x(end),y(end)),"-r*",'linewidth',7)

end

% Function to automatically save plots in high resolution

function savePlot(name)

% Resize current figure to fullscreen for higher resolution image
set(gcf, 'Position', get(0, 'Screensize'));

% Save current figure with the specified name
saveas(gcf, join([name,'.jpg']));

% Resize current figure back to normal
set(gcf,'position',get(0,'defaultfigureposition'));

end