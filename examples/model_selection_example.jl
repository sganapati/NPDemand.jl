# ------------------------------------------------------------------
# Code to simulate logit data and estimate nonparametrically
# Plots estimates of own and cross-price elasticities
# Written by James Brand
# ------------------------------------------------------------------
using Statistics, NPDemand
using RCall, DataFrames¿
@rlibrary ggplot2

J=3; # products
T =500;
beta = -0.4; # price coefficient
sdxi = 0.15; # standard deviation of xi

S = 1;
G = 10; # size of grid on which to evaluate price elasticities
esep_own = zeros(S,G);
esep_cross = zeros(S,G);
esep_own_dist = zeros(S,T);
esepTrue = zeros(S,G);

s, pt, zt, xi = NPDemand.simulate_logit(J,T, beta, sdxi);

p_points = range(quantile(pt[:,1],.25),stop = quantile(pt[:,1],.75),length = G);
p_points = convert.(Float64, p_points)

# ------------------------------------------------------
# Set options for estimation and elasticity calculation
# ------------------------------------------------------
bernO = 3*ones(2J,1);        # Order of Bernstein Polynomial
iv=1;                       # Order of IV Polynomial = (bernO + iv)
constrained = 0;            # Monotonicity Constraint (experience says you always want this on)
xt = zeros(T,2J);       # No exogenous product characteristics
trueS = 0;                    # Evaluate at true market shares or not
own = [1,1];                # [derivative of j, with respect to price of k]
cross = [1,2];
nfolds = 5; # number of cross-validation folds
nlam = 10; # number of regularization parameters to try. Actual values chosen automatically by hierNet
strong = true; # boolean for whether or not to impose strong hierarchy constraint
# Note: "strong = true" takes much longer than "strong = false."
nboot = 10;

# ------------------------------------------------------
# Simulation
# ------------------------------------------------------

included_symmetric_pct = zeros(2J,2J)
included_pct = zeros(2J,2J)
for si = 1:1:S
    s, pt, zt = NPDemand.simulate_logit(J,T, beta, sdxi);
    s2, pt2, zt2  = NPDemand.simulate_logit(J,T, beta, sdxi);

    s = [s s2];
    s = s ./ 2;
    pt = [pt pt2];
    zt = [zt zt2];

    # hierNet() Returns two matrices: one, the "raw" selected model, and another
    #   which imposes symmetry. I.e. if j is a substute for k, then k is
    #   a substitute for j as well (this can drastically increase the # parameters
    #    to estimate when s has many columns)
    included, included_symmetric = NPDemand.hierNet_boot(s, pt, zt, nfolds, nlam, false, nboot);

    # Estimate demand nonparametrically
        # If you want to include an additional covariate in all demand
        # functions, add an additional argument "marketvars" after included. If it is an
        # additional product characteristic, marketvars should be T x J
    inv_sigma, designs = NPDemand.inverse_demand(s, pt, xt, zt, bernO, iv, 2J, constrained, included_symmetric, nothing);

    # Calculate price elasticities
    deltas = -1*median(pt).*ones(G,2J);
    deltas[:,1] = -1*p_points;
    JMB most recent issue is here. issues with trueS=1, and with trueS=0 + model selection
    esep, Jacobians, share_vec = NPDemand.price_elasticity_priceIndex(inv_sigma, s, p_points, deltas, bernO, own, included_symmetric, trueS,[]);
    trueEsep = beta.*p_points.*(1 .- share_vec[:,1])
    #
    esep_own[si,:] = esep;
    esepTrue[si,:] = trueEsep;
    included_pct[:,:] += included./S;
    included_symmetric_pct[:,:] += included_symmetric./S;
end

esep025 = zeros(G,1)
esep50 = zeros(G,1)
esep975 = zeros(G,1)
for i = 1:G
    esep025[i] = quantile(esep_own[:,i], 0.1)
    esep50[i] = quantile(esep_own[:,i], 0.5)
    esep975[i] = quantile(esep_own[:,i], 0.9)
end
esep025 = dropdims(esep025,dims = 2)
esep50 = dropdims(esep50,dims = 2)
esep975 = dropdims(esep975,dims = 2)

df = DataFrame(p = p_points, e025 = esep025, e50 = esep50, e975 = esep975)
ggplot(df, aes(x=:p, y=:e50)) + geom_line() + geom_line(aes(y=:e975), color = "gray", linetype = "dashed") +
    geom_line(aes(y=:e025), color = "gray", linetype = "dashed") +
    xlab("Price") + ylab("Own-Elasticity") + theme_light()