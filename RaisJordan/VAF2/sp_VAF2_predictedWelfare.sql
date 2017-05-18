USE [Xform]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

alter Proc [XForm].[sp_VAF2_predictedWelfare] @UUID NVARCHAR(MAX)
as
Declare 
@xml as xml,
@rootName nvarchar(max),
@caseNo nvarchar(max),
	@enterType nvarchar(max),
	@errorText nvarchar(max), -- for error reporting

-- Final VAF Rating
@VAFpredictedWelfareRating int,
	@predictedWelfare decimal(18,12),
	@predictedWelfarePerCapita decimal(18, 12),

-- Family Rating
@ratingFamilySize decimal(18, 12),
	@familySize int,
	@CaseSize2Coeff decimal(18, 12), 
	@CaseSize3Coeff decimal(18, 12),
	@CaseSize4Coeff decimal(18, 12),
	@CaseSize5Coeff decimal(18, 12),
	@CaseSize6Coeff decimal(18, 12),
	@CaseSize7Coeff decimal(18, 12),
	@CaseSize8PlusCoeff decimal(18, 12),

-- Children Rating
@ratingChildren decimal(18,12),
	@numOfChildren int,
	@ChildrenCoeff1 decimal(18, 12),
	@ChildrenCoeff2 decimal(18, 12),
	@ChildrenCoeff3 decimal(18, 12),
 
-- Crowding Rating
@ratingCrowding decimal(18,12),
	@allHouseholdMembers int,
	@householdRooms int,
	@CrowdingCoeff decimal(18, 12),	

-- Occupancy Rating
@ratingOccupancy decimal(18,12),
	@occupancyPayRent nvarchar(max),
	@occupancyDetail nvarchar(max),
	@OccupancyCoeff1 decimal(18, 12),
	@OccupancyCoeff2 decimal(18, 12),
	@OccupancyCoeff3 decimal(18, 12),
	@OccupancyCoeff4 decimal(18, 12),

-- PA Gender Rating
@ratingPAGender decimal(18,12),
	@PAGender nvarchar(max),
	@PAGenderCoeff decimal(18, 12),

-- Marital Status Rating
@ratingMaritalStatus decimal(18,12),
	@maritalStatus nvarchar(max),
	@MaritalStatusCoeff1 decimal(18, 12),
	@MaritalStatusCoeff2 decimal(18, 12),
	@MaritalStatusCoeff3 decimal(18, 12),

-- MOI Rating
@ratingMOI decimal(18,12),
	@governate nvarchar(max),
	@MOIAjlounCoeff decimal(18, 12),
	@MOIAqabahCoeff decimal(18, 12),
	@MOIBalqaCoeff decimal(18, 12), 
	@MOIIrbidCoeff decimal(18, 12), 
	@MOIJerashCoeff decimal(18, 12), 
	@MOIKarakCoeff decimal(18, 12), 
	@MOIMaanCoeff decimal(18, 12),
	@MOIMadabaCoeff decimal(18, 12),
	@MOIMafraqCoeff decimal(18, 12), 
	@MOITafilahCoeff decimal(18, 12), 
	@MOIZarqaCoeff decimal(18, 12), 

-- Working Family Memeber Rating
@ratingWorkingFamilyMemeber decimal(18,12),
	@workingFamilyMemeberCount int,
	@WorkingFamilyMemberCoeff decimal(18, 12),

-- Enumerator Judgement Rating
@ratingEnumeratorJudgement decimal(18,12),
	@enumeratorJudgement nvarchar(max),
	@EnumeratorJudgementCoeff decimal(18, 12),

-- Household Size Rating
@ratingHouseHoldSize decimal(18, 12),
@ratingHouseholdSizeSquared decimal(18, 12),
	@HouseHoldSizeCoeff decimal(18, 12), 
	@HouseHoldSizeSquaredCoeff decimal(18, 12)

SET NOCOUNT ON
-- get xml doc
begin
	set @caseNo = ''
	set @errorText = ''

	select @xml = InstanceXml from XForm.FormInstance where UUID = @UUID

	select @rootName = dataDetails.value('local-name(.)' , 'nvarchar(max)') from @xml.nodes ('./*') data(dataDetails) 

	select @xml = replace(cast(InstanceXml as nvarchar(max)) , @rootName , 'Root') 
		from XForm.FormInstance where UUID = @UUID

	-- Get caseNo either from Barcode or Manual entry
	select @enterType = data.dataDetails.value('(.)[1]' , 'nvarchar(max)')
		from  @xml.nodes ('/Root/VolunteerInformation/UnhcrEnteringType') data(dataDetails)

	if (@enterType = 'barcode') begin
		select @caseNo = data.dataDetails.value('(.)[1]' , 'nvarchar(max)')
			from  @xml.nodes ('/Root/VolunteerInformation/UnhcrFileNumberBarcode') data(dataDetails)
	end
	else begin
		-- Form constraint enforces manual1 and manual2 equal, no need to check here
		select @caseNo = data.dataDetails.value('(.)[1]' , 'nvarchar(max)')
			from  @xml.nodes ('/Root/VolunteerInformation/UnhcFileNumberManual2') data(dataDetails)
	end

	if (@caseNo = '' or @caseNo = null) begin
		set @errorText = 'Error: no case number'
		select @errorText errorText
		return
	end
end

-- Family Size Rating.
begin
	-- set coefficients
	Set @CaseSize2Coeff = -0.345039568
	Set @CaseSize3Coeff = -0.405953163
	Set @CaseSize4Coeff = -0.550424997
	Set @CaseSize5Coeff = -0.643290986
	Set @CaseSize6Coeff =  -0.708928535
	Set @CaseSize7Coeff = -0.785706965
	Set @CaseSize8PlusCoeff = -0.844660854

	select @familySize = data.dataDetails.value('(.)[1]' , 'nvarchar(max)')
	 from  @xml.nodes ('/Root/HouseholdInformation/FamilySize') data(dataDetails)

	if (@familySize = 1)
		set @ratingFamilySize = 0
	else if (@familySize = 2)
		set @ratingFamilySize = @CaseSize2Coeff
	else if (@familySize = 3)
		set @ratingFamilySize = @CaseSize3Coeff
	else if (@familySize = 4)
		set @ratingFamilySize = @CaseSize4Coeff
	else if (@familySize = 5)
		set @ratingFamilySize = @CaseSize5Coeff
	else if (@familySize = 6)
		set @ratingFamilySize = @CaseSize6Coeff
	else if (@familySize = 7)
		set @ratingFamilySize = @CaseSize7Coeff
	else if (@familySize >= 8)
		set @ratingFamilySize = @CaseSize8PlusCoeff
end

-- Children Rating.
begin
	-- set coefficients
	set @ChildrenCoeff1 = -0.048008886
	set @ChildrenCoeff2 = -0.113647224
	set @ChildrenCoeff3 = -0.099909477  

	select @numOfChildren = COUNT(*) from RegionalSearch.SyncSearchIndividuals
		where CaseNo = @caseNo and IndividualAge >= 0 and IndividualAge <= 14 and ProcessStatus = 'A' 

	if (@familySize = 0 )
		set @ratingChildren = 0
	else if (@numOfChildren = 0)
		set @ratingChildren = 0
	else if (@numOfChildren/(@familySize*1.0) < 0.5)
		set @ratingChildren =  @ChildrenCoeff1
	else if (@numOfChildren/(@familySize*1.0) >= 0.5 and @numOfChildren/(@FamilySize*1.0) < 0.75)
		set @ratingChildren = @ChildrenCoeff2
	else if (@numOfChildren/(@familySize*1.0) >= 0.75)
		set @ratingChildren = @ChildrenCoeff3
end

-- Crowding Rating
begin
	-- set coefficient
	set @CrowdingCoeff = -0.059158621

	select @AllHouseholdMembers = data.dataDetails.value('(.)[1]' , 'nvarchar(max)')
		from  @xml.nodes ('/Root/Housing/ShelterConditions/NumberOfIndividuals') data(dataDetails) 

	select @HouseholdRooms = data.dataDetails.value('(.)[1]' , 'nvarchar(max)')
	 from  @xml.nodes ('/Root/Housing/ShelterConditions/NumberOfRoom') data(dataDetails)

	if (@HouseholdRooms > 0)
		set @ratingCrowding =  (@CrowdingCoeff * @AllHouseholdMembers) / @HouseholdRooms
	else
		set @ratingCrowding = 0
end

--Occupancy Type Rating
begin
	-- set coefficients
	set @OccupancyCoeff1 = -0.694149032
	set @OccupancyCoeff2 = -0.525697133
	set @OccupancyCoeff3 = -0.661402814
	set @OccupancyCoeff4 =  -0.631949647

	-- Pays Rent?
	select @occupancyPayRent = data.dataDetails.value('(.)[1]' , 'nvarchar(max)')
		 from  @xml.nodes ('/Root/Housing/PaymentAndEvictionThreat/RentedAccommodation') data(dataDetails)

	if (@occupancyPayRent = 'Yes') begin
		select @occupancyDetail = data.dataDetails.value('(.)[1]' , 'nvarchar(max)')
			 from  @xml.nodes ('/Root/Housing/PaymentAndEvictionThreat/HowDoYouPayRent') data(dataDetails)
	end
	else begin
		select @occupancyDetail = data.dataDetails.value('(.)[1]' , 'nvarchar(max)')
			 from  @xml.nodes ('/Root/Housing/PaymentAndEvictionThreat/NotPayingRent') data(dataDetails)	
	end
		
	if (@occupancyDetail = 'SalaryFromWork' or @occupancyDetail = 'BorrowMoney' or @occupancyDetail = 'UseSaving' or @occupancyDetail = 'AssistanceFromFamilyAbroad' )
		set @ratingOccupancy = 0
	else if (@occupancyDetail = 'AssistanceFromAIDAgencies')
		set @ratingOccupancy = @OccupancyCoeff1
	else if (@occupancyDetail = 'Owned' or @occupancyDetail = 'DontPay')
		set @ratingOccupancy = @OccupancyCoeff2
	else if (@occupancyDetail = 'InKind')
		set @ratingOccupancy = @OccupancyCoeff3
	else if (@occupancyDetail = 'Squatter' or @occupancyDetail = 'Begging')
		set @ratingOccupancy = @OccupancyCoeff4
	else
		set @ratingOccupancy = 0
end

-- PA Gender Rating
begin
	-- set coefficient
	set @PAGenderCoeff = 0.128669231

	select @PAGender = Sex from RegionalSearch.SyncSearchIndividuals 
		where CaseNo = @caseNo and Rel = 'PA'

	if (@PAGender = 'M')
		set @ratingPAGender = @PAGenderCoeff
	else
		set @ratingPAGender = 0
end

-- Martial Status Rating
begin
	-- set coefficients
	set @MaritalStatusCoeff1 = -0.049040738
	set @MaritalStatusCoeff2 = 0.067978699
	set @MaritalStatusCoeff3 = 0.053102834

	Select @maritalStatus = MarriageStatusCode from RegionalSearch.SyncSearchIndividuals
		where Rel = 'PA' and CaseNo = @caseNo 

	if (@MaritalStatus = 'SN')
		set @ratingMaritalStatus = @MaritalStatusCoeff1
	else if (@MaritalStatus = 'MA' or @MaritalStatus = 'EG')
		set @ratingMaritalStatus = @MaritalStatusCoeff2
	else if (@MaritalStatus = 'DV' or @MaritalStatus = 'SR' or @MaritalStatus = 'WD')
		set @ratingMaritalStatus = @MaritalStatusCoeff3
	else
		set @ratingMaritalStatus = 0
end

--MOI score.
begin
	-- set coefficients
	set @MOIAjlounCoeff = -0.184725436
	set @MOIAqabahCoeff = -0.132024803
	set @MOIBalqaCoeff = -0.117795123
	set @MOIIrbidCoeff = -0.115281761
	set @MOIJerashCoeff = -0.131882198
	set @MOIKarakCoeff = -0.221706904
	set @MOIMaanCoeff = -0.096149262
	set @MOIMadabaCoeff = -0.0611488
	set @MOIMafraqCoeff = -0.027316206
	set @MOITafilahCoeff = -0.062341884
	set @MOIZarqaCoeff = -0.201517452

	select @governate = data.dataDetails.value('(.)[1]' , 'nvarchar(max)')
		from  @xml.nodes ('/Root/HouseholdInformation/Governorate') data(dataDetails)

	if (@governate = 'Ajloun')
		set @ratingMOI = @MOIAjlounCoeff
	else if (@governate = 'Aqaba')
		set @ratingMOI = @MOIAqabahCoeff
	else if (@governate = 'Balqa')
		set @ratingMOI = @MOIBalqaCoeff
	else if (@governate = 'Irbid')
		set @ratingMOI = @MOIIrbidCoeff
	else if (@governate = 'Jerash')
		set @ratingMOI = @MOIJerashCoeff
	else if (@governate = 'Karak')
		set @ratingMOI = @MOIKarakCoeff
	else if (@governate = 'Maan')
		set @ratingMOI = @MOIMaanCoeff
	else if (@governate = 'Madaba')
		set @ratingMOI = @MOIMadabaCoeff
	else if (@governate = 'Mafraq')
		set @ratingMOI = @MOIMafraqCoeff
	else if (@governate = 'Tafileh')
		set @ratingMOI = @MOITafilahCoeff
	else if (@governate = 'Zarqa')
		set @ratingMOI = @MOIZarqaCoeff
	else 
		set @ratingMOI = 0
end

-- Working family member
begin
	-- set coeffiecent
	set @WorkingFamilyMemberCoeff = 0.13636478

	select @workingFamilyMemeberCount = count(*) from (
		select data.dataDetails.value('(.)[1]' , 'nvarchar(max)') as WORK
			from  @xml.nodes ('/Root/IndividualInformations/IndividaulBioData/DoYouWork') data(dataDetails)
		) as Result
		where WORK = 'Yes'

	if (@workingFamilyMemeberCount > 0)
		set @ratingWorkingFamilyMemeber = @WorkingFamilyMemberCoeff
	else
		set @ratingWorkingFamilyMemeber = 0
end

-- Enumerator Judgement
begin
	-- set coefficient
	set @EnumeratorJudgementCoeff = 0.201133551

	select @enumeratorJudgement = data.dataDetails.value('(.)[1]' , 'nvarchar(max)')
		from  @xml.nodes ('/Root/Protection/FamilyClassification') data(dataDetails)
	
	if (@enumeratorJudgement = 'NotVulnerable')
		set @ratingEnumeratorJudgement = @EnumeratorJudgementCoeff
	else
		set @ratingEnumeratorJudgement = 0
end

-- Household Size Rating
begin
	-- set coefficients
	set @HouseHoldSizeCoeff = -0.053424225
	set @HouseHoldSizeSquaredCoeff = 0.000964602

	set @ratingHouseHoldSize = @HouseHoldSizeCoeff * @AllHouseholdMembers
	set @ratingHouseholdSizeSquared = @HouseHoldSizeSquaredCoeff * @AllHouseholdMembers * @AllHouseholdMembers
end

-- Predicted Welfare Per Capita
begin
	set @PredictedWelfarePerCapita = exp (4.832458632 + @ratingFamilySize + @ratingChildren + @ratingCrowding + @ratingOccupancy + @ratingPAGender + @ratingMaritalStatus + 
		@ratingMOI + @ratingWorkingFamilyMemeber + @ratingEnumeratorJudgement + @ratingHouseHoldSize + @ratingHouseholdSizeSquared)
end

-- Welfare Rating
begin
	if (@PredictedWelfarePerCapita > 100)
		set @VAFpredictedWelfareRating = 1
	if (@PredictedWelfarePerCapita >= 68 and @PredictedWelfarePerCapita < 100 )
		set @VAFpredictedWelfareRating = 2
	if (@PredictedWelfarePerCapita >= 28 and @PredictedWelfarePerCapita < 68 )
		set @VAFpredictedWelfareRating = 3
	if (@PredictedWelfarePerCapita < 28 )
		set @VAFpredictedWelfareRating = 4
end

-- Output
Select @caseNo CaseNo,
	@VAFpredictedWelfareRating VAFpredictedWelfareRating, 
	@predictedWelfarePerCapita predictedWelfarePerCapita,
	@ratingFamilySize ratingFamilySize,
	@ratingChildren ratingChildren,
	@ratingCrowding ratingCrowding,
	@ratingOccupancy ratingOccupancy,
	@ratingPAGender ratingPAGender,
	@ratingMaritalStatus ratingMaritalStatus,
	@ratingMOI ratingMOI,
	@ratingWorkingFamilyMemeber ratingWorkingFamilyMember, 
	@ratingEnumeratorJudgement ratingEnumeratorJudgement,
	@ratingHouseHoldSize ratingHouseholdSize,
	@ratingHouseholdSizeSquared ratingHouseholdSizeSquared