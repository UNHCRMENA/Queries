
Select distinct FormConfigId , FormUUID , B.RationCardID , B.ProcessingGroupNumber from XForm.FormToEntityMappingLog inner join RegionalSearch.SyncSearchRationCard B on (EntityId = B.RationCardGUID )
where FormUUID in (
Select FormUUID from XForm.FormToEntityMappingLog where EntityId in 
(Select IndividualId from RegionalSearch.SyncSearchIndividuals where CaseNo in (
Select CaseNo from RegionalSearch.SyncSearchIndividuals where Rel = 'PA' 
group by CaseNo having count(*) > 1 ))) and EntityName = 'SyncSearchRationCard'


