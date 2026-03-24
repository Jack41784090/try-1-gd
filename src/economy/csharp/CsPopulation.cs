using System;
using System.Collections.Generic;

namespace Condor.Economy;

public sealed class CsPopulation
{
    public List<CsPerson> People { get; } = new();
    private readonly Dictionary<SocialClass, List<CsPerson>> _byClass = new();
    private readonly Dictionary<JobType, List<CsPerson>> _byJob = new();
    private bool _sortedDirty = true;
    private CsPerson[] _cachedSorted = Array.Empty<CsPerson>();

    public void AddPerson(CsPerson person)
    {
        People.Add(person);
        IndexPerson(person);
        _sortedDirty = true;
    }

    public void RemovePerson(CsPerson person)
    {
        People.Remove(person);
        if (_byClass.TryGetValue(person.SocialClass, out var classList))
            classList.Remove(person);
        if (_byJob.TryGetValue(person.Job, out var jobList))
            jobList.Remove(person);
        _sortedDirty = true;
    }

    private void IndexPerson(CsPerson person)
    {
        if (!_byClass.TryGetValue(person.SocialClass, out var classList))
        {
            classList = new List<CsPerson>();
            _byClass[person.SocialClass] = classList;
        }
        classList.Add(person);

        if (!_byJob.TryGetValue(person.Job, out var jobList))
        {
            jobList = new List<CsPerson>();
            _byJob[person.Job] = jobList;
        }
        jobList.Add(person);
    }

    public void NotifyClassChanged(CsPerson person, SocialClass oldClass, JobType oldJob)
    {
        if (_byClass.TryGetValue(oldClass, out var oldClassList))
            oldClassList.Remove(person);
        if (_byJob.TryGetValue(oldJob, out var oldJobList))
            oldJobList.Remove(person);
        IndexPerson(person);
        _sortedDirty = true;
    }

    public List<CsPerson> GetByClass(SocialClass socialClass)
    {
        return _byClass.TryGetValue(socialClass, out var list) ? list : new List<CsPerson>();
    }

    public List<CsPerson> GetByJob(JobType job)
    {
        return _byJob.TryGetValue(job, out var list) ? list : new List<CsPerson>();
    }

    public float GetTotalDemand(int thingIdx)
    {
        float total = 0f;
        for (int i = 0; i < People.Count; i++)
            total += People[i].GetWant(thingIdx);
        return total;
    }

    public float GetTotalSupply(int thingIdx)
    {
        float total = 0f;
        for (int i = 0; i < People.Count; i++)
            total += People[i].GetInventory(thingIdx);
        return total;
    }

    public float GetAverageSatisfaction()
    {
        if (People.Count == 0) return 0f;
        float total = 0f;
        for (int i = 0; i < People.Count; i++)
            total += People[i].Satisfaction;
        return total / People.Count;
    }

    public float GetAverageMoney()
    {
        if (People.Count == 0) return 0f;
        float total = 0f;
        for (int i = 0; i < People.Count; i++)
            total += People[i].Money;
        return total / People.Count;
    }

    public int Size() => People.Count;

    public void MarkWealthDirty() => _sortedDirty = true;

    public CsPerson[] SortedByWealthDesc()
    {
        if (_sortedDirty)
        {
            _cachedSorted = People.ToArray();
            Array.Sort(_cachedSorted, (a, b) => b.Money.CompareTo(a.Money));
            _sortedDirty = false;
        }
        return _cachedSorted;
    }

    public static List<CsPerson> CreateBatch(
        int count, string namePrefix, SocialClass socialClass,
        JobType job, float startingMoney, int goodsCount)
    {
        var batch = new List<CsPerson>(count);
        for (int i = 0; i < count; i++)
        {
            batch.Add(CsPerson.Create(
                $"{namePrefix}_{i + 1}", socialClass, job, startingMoney, goodsCount));
        }
        return batch;
    }
}
