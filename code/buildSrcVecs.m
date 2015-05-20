%%%
%
% Gather src hidden vectors for attention-based models.
% For each sentence ii, we extract a set of vectors to pay attention to
%   srcVecsAll(:, ii, srcPositions(ii)-posWin:srcPositions(ii)+posWin)
%   and put it into srcVecs(:, ii, :). Boundary cases are handled as well.
%
% Thang Luong @ 2015, <lmthang@stanford.edu>
%
%%% 

% TODO move srcMaxLen out
% IMPORTANT: we assume the sentences are reversed here
% srcPositions = srcMaxLen - srcPositions
function [srcVecsSub, linearIdSub, linearIdAll] = buildSrcVecs(srcVecsAll, srcPositions, flags, params) % startAttnIds, endAttnIds, startIds, endIds, indices
  posWin = params.posWin;
  numAttnPositions = 2*posWin+1;
  [lstmSize, batchSize, numSrcHidVecs] = size(srcVecsAll);
  
  % masking
  srcPositions(~flags) = [];
  unmaskedIds = find(flags);
  
  % init. IMPORTANT: don't swap these two lines
  leftIndices = reshape(repmat((1:numAttnPositions)', 1, length(unmaskedIds)), 1, []);
  unmaskedIds = reshape(repmat(unmaskedIds, numAttnPositions, 1), 1, []);
  
  
  % Note: generate multiple sequences of the same lengths without using for loop, see this post for many elegant solutions
  % http://www.mathworks.com/matlabcentral/answers/217205-fast-ways-to-generate-multiple-sequences-without-using-for-loop
  % The below version is the only solution that is faster than for loop (3 times).
  startAttnIds = srcPositions-posWin;
  indicesAll = reshape(bsxfun(@plus, startAttnIds(:), 0:(numAttnPositions-1))', 1, []); 
  
  % check those that are out of boundaries
  excludeIds = find(indicesAll>numSrcHidVecs | indicesAll<1);
  if ~isempty(excludeIds)
    indicesAll(excludeIds) = []; unmaskedIds(excludeIds) = []; leftIndices(excludeIds) = [];
  end
  
  % create linear indices
  linearIdSub = sub2ind([batchSize, numAttnPositions], unmaskedIds, leftIndices);
  linearIdAll = sub2ind([batchSize, numSrcHidVecs], unmaskedIds, indicesAll);
  
  % create srcVecs
  srcVecsSub = zeroMatrix([lstmSize, batchSize*numAttnPositions], params.isGPU, params.dataType);
  srcVecsAll = reshape(srcVecsAll, lstmSize, []);
  srcVecsSub(:, linearIdSub) = srcVecsAll(:, linearIdAll);
  srcVecsSub = reshape(srcVecsSub, [lstmSize, batchSize, numAttnPositions]);
  
  
%   % these variables access srcVecsAll, lstmSize * batchSize * numSrcHidVecs
%   % telling us where to pay our attention to.
%   startAttnIds = srcPositions-posWin;
%   endAttnIds = srcPositions + posWin;
%   
%   % these variables are for srcVecs, lstmSize * batchSize * numAttnPositions
%   % numAttnPositions = 2*posWin+1
%   startIds = ones(1, batchSize);
%   endIds = numAttnPositions*ones(1, batchSize);
%   
%   
%   
%   %% boundary condition for startAttnIds
%   indices = find(startAttnIds<1);
%   startIds(indices) = startIds(indices) - (startAttnIds(indices)-1);
%   startAttnIds(indices) = 1; % Note: don't swap these two lines
%   % here, we are sure that startHidId>=1, startAttnId>=1
%   
%   %% boundary condition for endAttnIds
%   indices = find(endAttnIds>numSrcHidVecs);
%   endIds(indices) = endIds(indices) - (endAttnIds(indices)-numSrcHidVecs);
%   endAttnIds(indices) = numSrcHidVecs; % Note: don't swap these two lines
%   % here, we are sure that endHidId<=numAttnPositions, endAttnId<=numSrcHidVecs
%   
%   %% last boundary condition checks
%   flags = startIds<=endIds & startAttnIds<=endAttnIds & flags;
%   % out of boundary
%   indices = find(~flags);
%   startIds(indices) = 1; endIds(indices) = 0; startAttnIds(indices) = 1; endAttnIds(indices) = 0;
%   % in boundary
%   indices = find(flags);
%   if length(srcPositions)==1 && ~isempty(indices) % special case, when all src positions are the same. srcPositions is a scalar.
%     srcVecs(:, :, startIds:endIds) = srcVecsAll(:, :, startAttnIds:endAttnIds);
%   else % different source positions
%     for ii=1:length(indices)
%       index = indices(ii);
%       srcVecs(:, index, startIds(index):endIds(index)) = srcVecsAll(:, index, startAttnIds(index):endAttnIds(index));
%     end
%   end
end