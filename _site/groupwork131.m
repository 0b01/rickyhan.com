%% Groupwork 1/31/2018.
% 

%% Question 1: do Exercise 4.3 and submit it by 2:15 pm. This is the quiz.

A = transpose([1 2 -1 0; 3 3 0 3]);
b = [0;0;0;1];
x = inv(A'*A)*A'*b;
x

%% Question 2.
% It's 2018, right? We have super-powerful computers. Why not just skip the
% whole "least squares" thing and fit a curve exactly? Good rhetorical
% question, me! Let's try that.

B = [1 5; 2 5; 3 5; 4 3; 5 4; 6 4; 7 4; 8 2];

%%
% a) B stands for Beethoven. Why?
% Because it's the Symphony 5 in C-(Fate)

%%
% b) Put Xn.m in your working path. What does Xn() do?
% It generates the basis of an n-degree polynomial.

%%
% Uncomment the following code, then explain why the output makes sense.

a = [3 -1 9 1]*Xn(3)
fplot(a)

% This makes sense because it is the plot of the function
% y = 3x^3 - x^2 + 9x + 1

%%
% c) Okay, now set up the augmented matrix that will let you solve for the interpolation polynomial; call it A. You'll probably find the following
% helpful:
% <https://en.wikipedia.org/wiki/Polynomial_interpolation#Constructing_the_interpolation_polynomial>

% help vander

% Great. Okay. Now just rref(A) and then hit the output with Xn(7) to get
% your polynomial p!

Mcoeffs = rref([vander([1:8]) B(:, 2)])
co = Mcoeffs(:,end)

%%
% Good job. Obviously we want to check that it does actually do what we say
% it does. So:

scatter(B(:,1),B(:,2),'filled')
hold on;

p = co' * Xn(7)
fplot(p)
axis([0 10 0 10])

%%
% d) If you did this right, your polynomial should go pretty much exactly
% through the first four points and then start to freak out. That's
% intentional; rref is awful. So instead *invert* the Vandermonde and
% multiply it by the output vector to get your coefficients. Call it q. Then plot
% that.


hold off;
scatter(B(:,1),B(:,2),'filled')
hold on;
q = (inv(vander(1:8)) * B(:,2))' * Xn(7)
fplot(q)
axis([0 10 0 10])
%%
% Okay now here's the real issue. 
syms x;
hold off;
runge = 1/(1+x^2);
fplot(runge)

%%
% Do polynomial interpolation for runge(x) on [-5,5] with 3 equally-spaced
% points.

Three = [-5 0 5]
Threepoints = [Three; subs(runge,x,Three)]

Y = (Threepoints(2,:))'
scatter(Three', Y','filled')
hold on;
len = length(Three);

invV = inv(vander(Three));
q = (invV * Y)' * Xn(len-1)

fplot(q)
axis([-5 5 -5 5])

%%
% Five.

interp(4)
%%
% Eleven.
interp(10)

%%
% 21.
interp(20)

%%

function interp(n)
    syms x;
    runge = 1/(1+x^2);
    Five = [-5:(10/n):5]
    Fivepoints = [Five; subs(runge,x,Five)]

    Y = (Fivepoints(2,:))'
    scatter(Five, Y,'filled')
    hold on;
    len = length(Y);

    invV = inv(vander(Five));
    q = (invV * Y)' * Xn(len-1)

    fplot(q)
    axis([-5 5 -5 5])

end