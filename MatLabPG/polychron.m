% Finds polychronous groups in the workspace generated by spnet.m
% and saved in the matlab file fname, e.g., fname = '3600.mat';
% Created by Eugene M.Izhikevich.           November 21, 2005
% Modified on April 2, 2008 based on suggestions of Petra Vertes (UK).

% Main idea: for each mother neuron, consider various combinations of
% pre-synatic (anchor) neurons and see whether any activity of a silent
% network could emerge if these anchors are fired.
clear;
clearvars -global

timestepMode=1;

model_izhikevich = 1;
model_conductanceLIAF = 2;
neuronModel = model_conductanceLIAF;


for trainedNet = [0,1]
    if (trainedNet)
        networkStatesName = 'networkStates_trained.mat'
    else
        networkStatesName = 'networkStates_untrained.mat'
    end

    initOn = 1;
    global a b c d N D pp s ppre dpre post pre delay T timestep di nLayers ExcitDim InhibDim
    if exist(networkStatesName,'file')
        load(networkStatesName);
        disp('**ATN** network state data previously stored are loaded')
    end

    % parameters %
    % val from the simulation
    M = 50; %number of syn per neurons
    ExcitDim = 64;
    InhibDim = 32;
    nLayers = 4;
    N = (ExcitDim*ExcitDim+InhibDim*InhibDim)*nLayers;% N: num neurons
    timestep = 0.00002;
    
    D = 10; % D: max delay
    T= 100;              % the max length of a group to be considered;
    if(timestepMode==1)
        T=2500;%1000;
        D = int32(D/(timestep*1000));
    end
    % parameters to be provided
    anchor_width=3;     % the number of anchor neurons, from which a group starts
    min_group_path=4;%7;   % discard all groups having shorter paths from the anchor neurons



    saveImages = 0;
    plotFigure = 0;


    if exist(networkStatesName,'file')==0
        
        % loading data %
        disp('**ATN** loading data')


        if(trainedNet)
            fileID = fopen('../output/Neurons_NetworkWeights.bin');
        else
            fileID = fopen('../output/Neurons_NetworkWeights_Initial.bin');
        end
        weights_loaded = fread(fileID,'float32');
        fclose(fileID);

        fileID = fopen('../output/Neurons_NetworkDelays.bin');
        delays_loaded = fread(fileID,'int32');
        fclose(fileID);

        fileID = fopen('../output/Neurons_NetworkPre.bin');
        preIDs_loaded = fread(fileID,'int32');
        fclose(fileID);

        fileID = fopen('../output/Neurons_NetworkPost.bin');
        postIDs_loaded = fread(fileID,'int32');
        fclose(fileID);
        
        
        cond = find(preIDs_loaded>=0);
        preIDs_loaded = preIDs_loaded(cond)+1; %index start from 1 in matlab
        postIDs_loaded = postIDs_loaded(cond)+1;
        weights_loaded = weights_loaded(cond);
        delays_loaded = delays_loaded(cond);
        
        if(timestepMode==0)
            delays_loaded = int32(delays_loaded*timestep*1000);
        end
        
        cond1 = mod(postIDs_loaded,(ExcitDim*ExcitDim+InhibDim*InhibDim))<=ExcitDim*ExcitDim;
        cond2 = postIDs_loaded > preIDs_loaded;
        FFWeights = weights_loaded(find(cond2==1 & cond1==1));
        figure;
        hist(FFWeights);
        title('Feed Forward Weight Distributions');
        
        %uncomment the command below to test the algorithm for shuffled (randomized e->e) synapses
        %e2e = find(s>=0 & post<Ne); s(e2e) = s(e2e(randperm(length(e2e))));

        groups={};          % the list of all polychronous groups



        % Make necessary initializations to speed-up simulations.

        %find max numPostSynCon:
        maxNumPostSynCon = 0;
        for i=1:N
            postListLen = length(find(preIDs_loaded==i));
            if maxNumPostSynCon<postListLen
                maxNumPostSynCon = postListLen;
            end
        end;

        post = zeros(N,maxNumPostSynCon);
        delay = zeros(N,maxNumPostSynCon)+1;
        s = zeros(N,maxNumPostSynCon);

        %ppre and pre contain lists of presynaptic ids connected to post synaptic
        %cell i
        pre = cell(1,N);%stores index of PreSynapse (nCells x nPreSynCons)
        ppre = cell(1,N);
        dpre = cell(1,N);
        pp = cell(1,N);

        for i_pre=1:N
            cond = preIDs_loaded == i_pre;

            delays_tmp = delays_loaded(cond);
            delay(i_pre,1:length(delays_tmp))=delays_tmp;
            % This matrix provides the delay values for each synapse.
            %delay values of synapses that are connected from each presynaptic id i;
            % ie delay{i} return a list of delays of synapses that is connected from i

            post_tmp = postIDs_loaded(cond);
            post(i_pre,1:length(post_tmp))=post_tmp;
            %post synaptic ids that are connected from each presynaptic id i;
            %ie post{i} return a list of ids of synapses that is connected from i

            for post_id_index = 1:length(post_tmp)
                i_post=post_tmp(post_id_index);
                pre{i_post}(length(pre{i_post})+1,1)=(i_pre+N*(post_id_index-1));
                ppre{i_post}(length(ppre{i_post})+1,1)=i_pre;
            end

            s_tmp = weights_loaded(cond);
            s(i_pre,1:length(s_tmp))=s_tmp;
        end


        % %This cell element tells what the presynaptic delay is;
        for i_post=1:N
            dpre{i_post}=delay( pre{i_post} );
        end;

        %This cell element tells where to put PSPs in the matrix I (N by 1000)
        for i_post=1:N
            pp{i_post}=post(i_post,:)+N*(delay(i_post,:)-1);
        end;

        %plotDistributions(ppre,nLayers,ExcitDim,InhibDim);
        
        save(networkStatesName);
    end

    plotDistributions(ppre,nLayers,ExcitDim,InhibDim);
    
    
    if (neuronModel == model_conductanceLIAF)
        sm = 0.00004 * 0.0035;%0.0022;%18 ;%biological scaling constant
        %sm = 1.0;
        sm_threshold = 0.7*sm;
        sm_threshold_input = 0.90*sm;
        Excit2InhibRatio = 1.0;
        
        s = s*sm;
        s(find(s>0 & s<=sm_threshold))=0;%remove small vals
        
        di = s;
        reversal_potential_Vhat_excit = 0.0;
        reversal_potential_Vhat_inhib = -0.074;
        for l = 1:nLayers 
            excit_begin = (ExcitDim*ExcitDim+InhibDim*InhibDim)*(l-1)+1;
            excit_end = ExcitDim*ExcitDim*l + (InhibDim*InhibDim)*(l-1);
            di(excit_begin:excit_end,:)=s(excit_begin:excit_end,:)*reversal_potential_Vhat_excit;
            
            inhib_begin = ExcitDim*ExcitDim*l + (InhibDim*InhibDim)*(l-1) + 1;
            inhib_end = (ExcitDim*ExcitDim+InhibDim*InhibDim)*l;
            s(inhib_begin:inhib_end,:)=s(inhib_begin:inhib_end,:)*Excit2InhibRatio;
            di(inhib_begin:inhib_end,:)=s(inhib_begin:inhib_end,:)*reversal_potential_Vhat_inhib;
        end
        
        
    elseif (neuronModel == model_izhikevich)
        
        % izhikevich model params:
        a = zeros(N,1)+0.1;%0.02; %decay rate [0.02, 0.1]
        b = 0.2; %sensitivity [0.25, 0.2]
        c = -65;%reset [-65,-55,-50] potential after spike
        d = zeros(N,1)+8; %reset [2,4,8]
        %http://www.izhikevich.org/publications/spikes.pdf
        
        sm = 17.0;%18 ;%max synaptic weight
        sm_threshold = 0.8*sm;
        sm_threshold_input = 0.80*sm;
        E_IsynEfficRatio = 1.0;
    
        % multiply the weight by a constance used in the original analysis
        s = s*sm;
        %remove small values for the synaptic weights:
        s(find(s>0 & s<=sm_threshold))=0;%remove small vals
        % set inhibitory synaptic weight negative
        for l = 1:nLayers 
            i_begin = ExcitDim*ExcitDim*l + (InhibDim*InhibDim)*(l-1) + 1;
            i_end = (ExcitDim*ExcitDim+InhibDim*InhibDim)*l;
            s(i_begin:i_end,:)=s(i_begin:i_end,:)*-1*E_IsynEfficRatio;
        end
    end

    
    


    if (plotFigure)
        fig = figure('position', [0, 0, 2000, 1500]);
    end
    for i=1:(ExcitDim*ExcitDim)
%    for i=ExcitDim*ExcitDim/2:(ExcitDim*ExcitDim)
        i
        i_post = i + (ExcitDim*ExcitDim + InhibDim*InhibDim);%looking at the second layer
        anchors=1:anchor_width;                     % initial choice of anchor neurons

        pre_cells_FF = pre{i_post}(find(ppre{i_post}<=ExcitDim*ExcitDim)); %to exlude input from lateral connections

        strong_pre=find(s(pre_cells_FF)>sm_threshold_input);

    %     strong_pre=find(s(pre{i_post})>sm_threshold);    % list of the indecies of candidates for anchor neurons
        if length(strong_pre) >= anchor_width       % must be enough candidates
            while 1        % will get out of the loop via the 'break' command below
%                 anchors
                
                maxDelay = max(dpre{i_post}(strong_pre(anchors)))+1;
                gr=polygroup( ppre{i_post}(strong_pre(anchors)), maxDelay-dpre{i_post}(strong_pre(anchors)),neuronModel );

                %Calculate the longest path from the first to the last spike
                fired_path=sparse(N,1);        % the path length of the firing (from the anchor neurons)
                for j=1:length(gr.gr(:,2))
                    fired_path( gr.gr(j,4) ) = max( fired_path( gr.gr(j,4) ), 1+fired_path( gr.gr(j,2) ));
                end;
                longest_path = max(fired_path);

                if longest_path>=min_group_path

                    gr.longest_path = longest_path(1,1); % the path is a cell

                    % How many times were the spikes from the anchor neurons useful?
                    % (sometimes an anchor neuron does not participate in any
                    % firing, because the mother neuron does its job; such groups
                    % should be excluded. They are found when the mother neuron is
                    % an anchor neuron for some other neuron).
                    useful = zeros(1,anchor_width);
                    anch = ppre{i_post}(strong_pre(anchors));
                    for j=1:anchor_width
                        useful(j) = length( find(gr.gr(:,2) == anch(j) ) );
                    end;

                    if all(useful>=2)
    %                     ppre{i_post}(strong_pre(anchors))
                        groups{end+1}=gr;           % add found group to the list
                        disp([num2str(round(100*i/(ExcitDim*ExcitDim))) '%: groups=' num2str(c) ', size=' num2str(size(gr.firings,1)) ', path_length=' num2str(gr.longest_path)])   % display of the current status
                        if (plotFigure)
                            if(timestepMode)
                                plot(gr.firings(:,1)*timestep*1000,gr.firings(:,2),'o');
                            else
                                plot(gr.firings(:,1),gr.firings(:,2),'o');
                            end
                            hold on;
                            for l=1:nLayers
                                if(timestepMode)
                                    plot([0 T*timestep*1000],[(ExcitDim*ExcitDim+InhibDim*InhibDim)*l (ExcitDim*ExcitDim+InhibDim*InhibDim)*l],'k');
                                    plot([0 T*timestep*1000],[(ExcitDim*ExcitDim)*l+(InhibDim*InhibDim)*(l-1) (ExcitDim*ExcitDim)*l+(InhibDim*InhibDim)*(l-1)],'k--');
                                else
                                    plot([0 T],[(ExcitDim*ExcitDim+InhibDim*InhibDim)*l (ExcitDim*ExcitDim+InhibDim*InhibDim)*l],'k');
                                    plot([0 T],[(ExcitDim*ExcitDim)*l+(InhibDim*InhibDim)*(l-1) (ExcitDim*ExcitDim)*l+(InhibDim*InhibDim)*(l-1)],'k--');
                                end
                            end
                            for j=1:size(gr.gr,1)
                                if(timestepMode)
                                    plot(gr.gr(j,[1 3 5])*timestep*1000,gr.gr(j,[2 4 4]),'.-');
                                else
                                    plot(gr.gr(j,[1 3 5]),gr.gr(j,[2 4 4]),'.-');
                                end
                            end;
                            if(timestepMode)
                                axis([0 T*timestep*1000 0 N]);
                            else
                                axis([0 T 0 N]);
                            end
                            hold off
                            drawnow;
                        end
                        title('Polychroneous chains');
                        ylabel('Cell Index');
                        xlabel('Time [ms]')
                        if(plotFigure && saveImages)
                            saveas(fig,[num2str(trainedNet) '_poly_i_' num2str(i_post) strrep(mat2str(ppre{i_post}(strong_pre(anchors))), ';', '_') '.fig']);
                            saveas(fig,[num2str(trainedNet) '_poly_i_' num2str(i_post) strrep(mat2str(ppre{i_post}(strong_pre(anchors))), ';', '_') '.png']);
                        end
                    end;
                end
                
%                 length(gr.firings)

                % Now, get a different combination of the anchor neurons
                k=anchor_width;
                while k>0 & anchors(k)==length(strong_pre)-(anchor_width-k)
                    k=k-1;
                end;

                if k==0, break, end;    % exhausted all possibilities

                anchors(k)=anchors(k)+1;
                for j=k+1:anchor_width
                    anchors(j)=anchors(j-1)+1;
                end;

                pause(0); % to avoid feezing when no groups are found for long time

            end;
        end;
    end;

    if (trainedNet)
        save('groups_trained.mat','groups');
    else
        save('groups_untrained.mat','groups');
    end
    disp(length(groups))
    clear;
end
