{
  # GrapheneOS-style progressive delay calculation
  # Formula: 30 × 2^⌊(n-30)÷10⌋ for n ≥ 31
  calculateTimeoutDelay = attempts:
    if attempts >= 141
    then 24 * 3600 # 24 hours max
    else if attempts >= 31
    then let
      exp = (attempts - 30) / 10; # Integer division gives us floor
    in
      30 * (builtins.pow 2 exp)
    else if attempts >= 6
    then 30 # First timeout at 6 attempts
    else 0;

  # Number of attempts before first timeout (matching GrapheneOS)
  firstTimeoutAttempts = 6;
}
