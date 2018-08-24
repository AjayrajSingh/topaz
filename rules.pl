% submit_rule.

% In order to test this see:
% https://goto.google.com/apigee/services/quality/gitonborgadmin
% example:
%   $ gob-curl -X POST -H 'Content-Type: text/plain; charset=UTF-8' \
%     --data-binary @rules.pl \
%     https://fuchsia-review.googlesource.com/a/changes/147615/revisions/current/test.submit_rule
%
% The number (147615 above) is changed to the change number of the change you
% want to test. You'll receive json that will take 1 of 3 forms
%   1) Some kind of error. These error messages tend not to be very helpful.
%      To debug I just manually run though what should be happening mainly.
%   2) An array with a single object indicating what labels are
%      "need", "ok", or "may".
%   3) An array with multiple objects. This is an indiciation that there is
%      more than one way to satsify submit_rule. You should treat that as an
%      error but it generally just means you need to add a cut at the end of
%      one of your horn clauses.

% Enforce owners for public/dart/
submit_rule(S) :-
  gerrit:commit_delta('^public/dart/.+'),
  find_owners:submit_rule(S),
  !.

% default is default
submit_rule(S) :- gerrit:default_submit(S).
