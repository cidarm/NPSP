/*
    Copyright (c) 2019, Salesforce.org
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Salesforce.org nor the names of
      its contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/
/**
* @author Salesforce.org
* @date 2019
* @group Recurring Donations
* @description Controller extension for enhanced Recurring Donation enablement panel
*/
public with sharing class RD2_EnablementDelegate_CTRL extends STG_Panel {

    /***
    * @description Enablement service
    */
    @TestVisible
    private static RD2_EnablementService service {
        get {
            if (service == null) {
                service = new RD2_EnablementService();
            }
            return service;
        }
        set;
    }

    /***
    * @description Returns Day of Month field picklist value specific to enhanced Recurring Donations
    */
    @TestVisible
    private static String dayOfMonthPicklistValue {
        get {
            if (dayOfMonthPicklistValue == null) {
                dayOfMonthPicklistValue = RD2_Constants.DAY_OF_MONTH_LAST_DAY;
            }
            return dayOfMonthPicklistValue;
        }
        set;
    }

    /***
    * @description A unique enhanced Recurring Donation enablement panel Id
    */
    public override String idPanel() {
        return 'idPanelRD2Enablement';
    }

    /***
    * @description NPSP namespace: an empty string if unmanaged, or 'npsp' if managed
    */
    public String getNamespace() {
        return UTIL_Namespace.getNamespace();
    }

    /***
    * @description An empty method called from actionFunction to reRender panels when it completes
    */
    public void refreshPanels() {
        
    }


    /***
    * @description Loads the enablement state so the current completed and pending options can be displayed
    * @return String JSON representation of the current EnablementState
    */
    @AuraEnabled(cacheable=false)
    public static String loadState() {
        return JSON.serialize(getEnablementState());
    }

    /***
    * @description Retrieves the current enablement state
    * @return EnablementState
    */
    @TestVisible
    private static EnablementState getEnablementState() {
        EnablementState state = new EnablementState();

        try {
            String jsonState = UTIL_CustomSettingsFacade.getRecurringDonationsSettings().RecurringDonations2EnablementState__c;

            if (String.isNotBlank(jsonState)) {
                state = (EnablementState) JSON.deserialize(jsonState, EnablementState.class);
            }

            state.isReady = service.isRecurringDonations2Ready();
            state.isEnabled = service.isRecurringDonations2Enabled();

            if (String.isBlank(jsonState)) {
                state.isConfirmed = false;
                state.isMetaLaunched = false;
                state.isMetaConfirmed = false;
            } else {
                state.isMetaLaunched = state.isMetaLaunched && state.isEnabled;
                state.isMetaConfirmed = state.isMetaConfirmed && state.isMetaLaunched && hasMetaDeployCompleted();
            }

        } catch (Exception e) {
            throwAuraHandledException(e.getMessage());
        }

        return state;
    }

    /***
    * @description Tracks the enablement confirmation user action
    * @return void
    */
    @AuraEnabled
    public static void confirmEnablement() {
        EnablementState state = getEnablementState();
        state.isConfirmed = true;

        saveEnablementState(state);
    }

    /***
    * @description Tracks the enhanced Recurring Donation enablement user action
    * @return void
    */
    @AuraEnabled
    public static void enableEnhancement() {
        try {
            STG_Panel.stgService.stgRD.IsRecurringDonations2Enabled__c = true;

            if (!Test.isRunningTest()) {
                upsert STG_Panel.stgService.stgRD;
                UTIL_OrgTelemetry_SVC.asyncProcessNpspSettingsTelemetry();
            }
            System.enqueueJob(new EnablementQueueable(QueueableMode.ScheduleJobs));

        } catch (Exception e) {
            throwAuraHandledException(e.getMessage());
        }
    }

    /***
    * @description Returns metadata deploy link
    * @return String MetaDeploy URL
    */
    @AuraEnabled(cacheable=false)
    public static String getMetaDeployURL() {
        String urlFormat = 'https://install.salesforce.org/products/npsp/{0}npsp-rd2-pilot';
        String version;

        if (UTIL_Namespace.isCustomerOrg()) {
            UTIL_Version_API versionAPI = new UTIL_Version_API();

            //Note: the exception cannot be caught in Apex
            version = String.valueOf(versionAPI.requestVersion());
        }

        version = String.isBlank(version) ? '' : (version + '/');

        return String.format(
            urlFormat,
            new String[]{ version }
        );
    }

    /***
    * @description Tracks the MetaDeploy link click user action
    * @return void
    */
    @AuraEnabled
    public static void launchMetaDeploy() {
        EnablementState state = getEnablementState();
        state.isMetaLaunched = true;

        saveEnablementState(state);

        System.enqueueJob(new EnablementQueueable(QueueableMode.DisableRollup));
    }

    /***
    * @description Tracks the MetaDeploy install confirmation user action
    * @return void
    */
    @AuraEnabled
    public static void confirmMetaDeploy() {
        if (!hasMetaDeployCompleted()) {
            throwAuraHandledException(System.Label.RD2_EnablementMetaDeployConfirmError);
        }

        EnablementState state = getEnablementState();
        state.isMetaConfirmed = true;
        saveEnablementState(state);
    }

    /***
    * @description Checks if MetaDeploy has completed
    * @return Boolean
    */
    private static Boolean hasMetaDeployCompleted() {
        List<SelectOption> lastDayOfMonthOptions = UTIL_Describe.getSelectOptions(
            String.valueOf(npe03__Recurring_Donation__c.SObjectType),
            SObjectType.npe03__Recurring_Donation__c.fields.Day_Of_Month__c.Name
        );

        for (SelectOption option : lastDayOfMonthOptions) {
            if (option.getValue() == dayOfMonthPicklistValue) {
                return true;
            }
        }
        return false;
    }

    /***
    * @description Skips dry run and moves straight to the migration
    * @return void
    */
    @AuraEnabled
    public static void skipDryRun() {
        setMigrationEnabled(true);
    }

    /***
    * @description Skips migration and moves back to the dry run
    * @return void
    */
    @AuraEnabled
    public static void skipMigration() {
        setMigrationEnabled(false);
    }

    /***
    * @description Sets migration enabled state
    * @param isMigrationEnabled Indicates if migration is enabled
    * @return void
    */
    private static void setMigrationEnabled(Boolean isMigrationEnabled) {
        EnablementState state = getEnablementState();
        state.isMigrationEnabled = isMigrationEnabled;

        saveEnablementState(state);
    }

    /***
    * @description Starts the dry run data migration
    * @return Id Batch Job Id
    */
    @AuraEnabled
    public static Id runDryRun() {
        Id jobId;
        
        try {
            EnablementState state = getEnablementState();
            if (state.isMetaConfirmed) {
                state.isDryRun2 = true;
                saveEnablementState(state);
            } 

            RD2_DataMigrationDryRun_BATCH batch = new RD2_DataMigrationDryRun_BATCH();
            jobId = Database.executeBatch(batch, batch.batchSize);

        } catch (Exception e) {
            throwAuraHandledException(e.getMessage());
        }
        
        return jobId;
    }

    /***
    * @description Starts the data migration batch
    * @return Id Batch Job Id
    */
    @AuraEnabled
    public static Id runMigration() {
        Id jobId;
        try {
            RD2_DataMigration_BATCH batch = new RD2_DataMigration_BATCH();
            jobId = Database.executeBatch(batch, batch.batchSize);

        } catch (Exception e) {
            throwAuraHandledException(e.getMessage());
        }

        return jobId;
    }

    /***
    * @description Saves the current enablement state
    * @param state Enablement state
    * @return void
    */
    private static void saveEnablementState(EnablementState state) {
        try {
            //do not save variables obsolete in the saved enablement state
            state.isReady = null;
            state.isEnabled = null;

            //save the state
            STG_Panel.stgService.stgRD.RecurringDonations2EnablementState__c = JSON.serialize(state);

            if (!Test.isRunningTest()) {
                upsert STG_Panel.stgService.stgRD;
            }

        } catch (Exception e) {
            throwAuraHandledException(e.getMessage());
        }
    }

    /***
    * @description Stops the archive batch process
    */
    @AuraEnabled
    public static void stopProcessing(Id batchId) {
        if (batchId == null) {
            return;
        }

        try {            
            System.abortJob(batchId);

        } catch (Exception e) {
            throwAuraHandledException(e.getMessage());
        }
    }

    /***
    * @description Throws AuraHandledException
    * @param errMessage
    * @return void
    */
    private static void throwAuraHandledException(String errMessage) {
        AuraHandledException e = new AuraHandledException(errMessage);
        e.setMessage(errMessage);
        throw e;
    }



    /***
    * @description Represents enhanced Recurring Donation options and status
    */
    public class EnablementState {
        public Boolean isReady = false;
        public Boolean isConfirmed = false;
        public Boolean isEnabled = false;
        public Boolean isMetaLaunched = false;
        public Boolean isMetaConfirmed = false;
        public Boolean isDryRun2 = false;
        public Boolean isMigrationEnabled = false;
    }

    /**
    * @description Defines the modes that the Queueable enablement job runs in
    */
    public enum QueueableMode {
        ScheduleJobs,
        DisableRollup
    }

    /**
     * @description Queueable to schedule the new RD Job OR to disable a legacy CRLP
     * rollup for Recurring Donations. Queueable needed to avoid a Mixed DML Operation error.
     */
    private class EnablementQueueable implements Queueable {

        private QueueableMode mode;

        /**
        * @description Constructor
        * @param mode Job Mode
        */
        public EnablementQueueable(QueueableMode mode) {
            this.mode = mode;
        }

        /**
        * @description Execute for the queueable. Delegates processing to the appropriate service
        */
        public void execute(QueueableContext context) {

            switch on (mode) {
                when ScheduleJobs {
                    if (!Test.isRunningTest()) {
                        UTIL_MasterSchedulableHelper.setScheduledJobs();
                    }
                }

                when DisableRollup {
                    disableNextPaymentDateRollup();
                }
            }

        }

        /**
        * @description When Enhanced Recurring Donations is enabled, the "Next Donation Date" field
        * (npe03__Next_Payment_Date__c) is no longer calculated as a rollup, but instead is calculated
        * as a service process in many places during Enhanced Recurring Donations automation. The previous
        * rollup was inaccurate in what it calculated relative to the field label. In legacy RD, this
        * field actually contained the CloseDate of the earliest open Opportunity associated with the RD.
        * In Enhanced Recurring Donations this field will contain the "next" expected installment due date
        * where "next" means always in the future.
        */
        private void disableNextPaymentDateRollup() {
            List<Rollup__mdt> rdRollups = CRLP_Rollup_SEL.getRollupsBySummaryType().get(npe03__Recurring_Donation__c.SObjectType);
            if (rdRollups == null) {
                return;
            }

            CRLP_RollupCMT.Rollup cmtRollup;
            for (Rollup__mdt rlp : rdRollups) {
                if (rlp.Summary_Field__r.QualifiedApiName == 'npe03__Next_Payment_Date__c') {
                    cmtRollup  = new CRLP_RollupCMT.Rollup(rlp);
                    break;
                }
            }

            if (cmtRollup == null) {
                return;
            }

            // Disable/Hide the rollup and update the Description on the rollup to reflect the change
            cmtRollup.isDeleted = true;
            cmtRollup.isActive = false;
            cmtRollup.description += '\nThis rollup was disabled automatically when Enhanced Recurring Donations was enabled.';

            List<CRLP_RollupCMT.Rollup> rollups = new List<CRLP_RollupCMT.Rollup>{ cmtRollup };
            CRLP_ApiService.RollupMetadataHandler changeHandler = new CRLP_ApiService().sendChangeEvent(rollups);

            CRLP_ConfigBuilder_SVC.queueRollupConfigForDeploy(rollups);
            CRLP_ConfigBuilder_SVC.deployedQueuedMetadataTypes(changeHandler, changeHandler.params);
        }
    }

    

}
